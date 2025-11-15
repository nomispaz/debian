parted /dev/vda mklabel gpt
parted /dev/vda mkpart ESP fat32 1MiB 513MiB
parted /dev/vda set 1 esp on
parted /dev/vda mkpart primary ext4 513MiB 100%

mkfs.fat -F32 /dev/vda1
mkfs.ext4 /dev/vda2

mount /dev/vda2 /mnt
mkdir -p /mnt/boot/efi
mount /dev/vda1 /mnt/boot/efi

apt install debootstrap

debootstrap --variant=minbase sid /mnt "http://deb.debian.org/debian"

cp chroot.sh /mnt

mkdir -p /mnt/proc
mkdir -p /mnt/sys
mkdir -p /mnt/dev/pts

mount -t proc proc /mnt/proc
mount -t sysfs sys /mnt/sys
mount -o bind /dev /mnt/dev
mount -t devpts pts /mnt/dev/pts
chroot /mnt
