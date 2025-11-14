parted /dev/vda mklabel gpt
parted /dev/vda mkpart ESP fat32 1MiB 513MiB
parted /dev/vda set 1 esp on
parted /dev/vda mkpart primary ext4 513MiB 100%

mkfs.fat -F32 /dev/vda1
mkfs.ext4 /dev/vda2

mount /dev/vda2 /mnt
mkdir -p /mnt/boot/efi
mount /dev/vda1 /mnt/boot/efi

sudo apt install -y debootstrap ostree dracut grub-efi-amd64

mkdir -p /mnt/ostree/repo
ostree --repo=/mnt/ostree/repo init --mode=bare

BUILD=/tmp/debian-buildroot
mkdir -p $BUILD
debootstrap --variant=minbase sid $BUILD http://deb.debian.org/debian

mkdir -p $BUILD/usr
mv $BUILD/etc $BUILD/usr/etc

# OSTree does not accept device nodes, sockets, or special files
rm -rf "$BUILD"/{dev,proc,sys,run,tmp,var/tmp,mnt,media,swapfile,lost+found}

mkdir -p /mnt/ostree/repo
mkdir -p /mnt/ostree/deploy
mkdir -p /mnt/boot
mkdir -p /mnt/etc
mkdir -p /mnt/var

ostree --repo=/mnt/ostree/repo commit \
    --branch=debian/sid \
    --subject="Debian sid base" \
    $BUILD

ostree admin --sysroot=/mnt os-init debian

mkdir -p $DEPLOY/{dev,proc,sys,boot/efi}
mount --bind /dev $DEPLOY/dev
mount --bind /proc $DEPLOY/proc
mount --bind /sys $DEPLOY/sys
mount --bind /mnt/boot/efi $DEPLOY/boot/efi

cat > $BUILD/etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian sid main contrib non-free-firmware
EOF

cp /etc/resolv.conf $BUILD/etc/

cp chroot.sh /mnt

chroot $DEPLOY


