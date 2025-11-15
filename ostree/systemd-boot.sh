
#!/bin/bash
set -euo pipefail

# -------------------------
# CONFIGURATION
# -------------------------
MOUNTPOINT="/mnt"
BUILDROOT="/tmp/debian-buildroot"
OS_NAME="debian"
BRANCH_NAME="sid"
TARGET_DISK="/dev/vda"
EFI_PARTITION="${TARGET_DISK}sda1"        # EFI partition
ROOT_PARTITION="${TARGET_DISK}sda2"       # Root filesystem partition
ROOT_FS_TYPE="ext4"
DEBOOTSTRAP_SUITE="sid"
DEBOOTSTRAP_COMPONENTS="main,non-free-firmware"
DEBOOTSTRAP_MIRROR="http://deb.debian.org/debian"
DEBIAN_MIRROR="http://deb.debian.org/debian"
OSTREE_REPO="$MOUNTPOINT/ostree/repo"

# Kernel and package cache
APT_CACHE="/var/cache/apt/archives"

if [[ $(id -u) -ne 0 ]]; then
  echo "Run as root."
  exit 1
fi

read -p "⚠ WARNING: This will destroy ALL DATA on ${TARGET_DISK}. Proceed? [y/N]: " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
  echo "Aborting."
  exit 1
fi

# --- 1) partition and format (GPT, 1: EFI, 2: root) ---
echo "[1/14] Partitioning $TARGET_DISK..."
parted $TARGET_DISK mklabel gpt
parted $TARGET_DISK mkpart ESP fat32 1MiB 513MiB
parted $TARGET_DISK set 1 esp on
parted $TARGET_DISK mkpart primary ext4 513MiB 100%

EFI_PART="${TARGET_DISK}1"
ROOT_PART="${TARGET_DISK}2"

mkfs.fat -F32 $EFI_PART
mkfs.ext4 $ROOT_PART

echo "[2/14] Formatting partitions..."
mkfs.vfat -F32 "$EFI_PART"
mkfs.${ROOT_FS_TYPE} -F "$ROOT_PART"

# --- 2) mount root and EFI (ESP at /boot/efi) ---
echo "[3/14] Mounting target filesystems..."
mkdir -p "$MOUNTPOINT"
mount "$ROOT_PART" "$MOUNTPOINT"
mkdir -p "$MOUNTPOINT/boot"
mkdir -p "$MOUNTPOINT/boot/efi"
mount "$EFI_PART" "$MOUNTPOINT/boot/efi"

mkdir -p "$BUILDROOT"

# -------------------------
# 2. Bootstrap minimal Debian
# -------------------------
#

apt install -y debootstrap ostree dracut systemd-boot

debootstrap --variant=minbase --components="$DEBOOTSTRAP_COMPONENTS" \
            --arch=amd64 "$DEBOOTSTRAP_SUITE" "$BUILDROOT" "$DEBOOTSTRAP_MIRROR"

# Bind mounts for chroot
mount --bind --mkdir /dev "$BUILDROOT/dev"
mount --bind --mkdir /dev/pts "$BUILDROOT/dev/pts"
mount --bind --mkdir /proc "$BUILDROOT/proc"
mount --bind --mkdir /sys "$BUILDROOT/sys"
mount --bind --mkdir /run "$BUILDROOT/run"
mount --bind --mdir /dev/shm "$BUILDROOT/dev/shm"

chroot $BUILDROOT bash -c '
[ ! -e /dev/null ]     && mknod -m 666 /dev/null     c 1 3
[ ! -e /dev/zero ]     && mknod -m 666 /dev/zero     c 1 5
[ ! -e /dev/random ]   && mknod -m 666 /dev/random   c 1 8
[ ! -e /dev/urandom ]  && mknod -m 666 /dev/urandom  c 1 9
[ ! -e /dev/tty ]      && mknod -m 666 /dev/tty      c 5 0
[ ! -e /dev/console ]  && mknod -m 600 /dev/console  c 5 1
[ ! -e /dev/ptmx ]     && mknod -m 666 /dev/ptmx     c 5 2
'

# --- 4) prepare apt sources & copy resolv.conf so apt works in chroot ---
echo "[5/14] Preparing apt sources and DNS for chroot..."
cat > "$BUILDROOT/etc/apt/sources.list" <<EOF
deb $DEBIAN_MIRROR sid main contrib non-free-firmware
EOF

# reuse host apt cache if present
if [[ -d "$APT_CACHE" ]]; then
  mkdir -p "$BUILDROOT/var/cache/apt/archives"
  mount --bind "$APT_CACHE" "$BUILDROOT/var/cache/apt/archives"
fi

# copy host resolv.conf so DNS works in chroot
if [[ -f /etc/resolv.conf ]]; then
  cp -L /etc/resolv.conf "$BUILDROOT/etc/resolv.conf"
fi

# -------------------------
# 3. Install required packages
# -------------------------
echo "[7/14] chrooting to install linux-image and dracut..."
chroot "$BUILDROOT" /bin/bash -c "
set -e
export DEBIAN_FRONTEND=noninteractive
apt update
# install kernel, dracut and basic tools; you can add packages here
apt install -y --no-install-recommends linux-image-amd64 dracut sudo gnupg systemd-boot ostree
"

# -------------------------
# 4. Inject OSTree dracut module
# -------------------------
MODDIR="$BUILDROOT/usr/lib/dracut/modules.d/98ostree"
mkdir -p "$MODDIR"

wget -O "$MODDIR/module-setup.sh" \
    https://raw.githubusercontent.com/ostreedev/ostree/main/src/boot/dracut/module-setup.sh
wget -O "$MODDIR/ostree.conf" \
    https://raw.githubusercontent.com/ostreedev/ostree/main/src/boot/dracut/ostree.conf

chmod 755 "$MODDIR/module-setup.sh"
chmod 644 "$MODDIR/ostree.conf"
chown -R root:root "$MODDIR"

# Minimal ostree binary and systemd unit (needed for dracut to include module)
mkdir -p "$BUILDROOT/usr/lib/ostree" "$BUILDROOT/usr/lib/systemd/system"
cat > "$BUILDROOT/usr/lib/ostree/ostree-prepare-root" <<'EOF'
#!/bin/sh
exec /usr/bin/true
EOF
chmod 755 "$BUILDROOT/usr/lib/ostree/ostree-prepare-root"

cat > "$BUILDROOT/usr/lib/systemd/system/ostree-prepare-root.service" <<'EOF'
[Unit]
DefaultDependencies=no
Before=initrd-root-fs.target
[Service]
Type=oneshot
ExecStart=/usr/lib/ostree/ostree-prepare-root
[Install]
WantedBy=initrd-root-fs.target
EOF
chmod 644 "$BUILDROOT/usr/lib/systemd/system/ostree-prepare-root.service"

# Ensure module is forced into initramfs
mkdir -p "$BUILDROOT/etc/dracut.conf.d"
cat > "$BUILDROOT/etc/dracut.conf.d/99-ostree.conf" <<'EOF'
add_dracutmodules+=" ostree "
hostonly="no"
EOF

# --- 7) run dracut inside buildroot to produce initramfs (works because kernel installed and /dev/proc mounted) ---
echo "[8/14] Generating initramfs in buildroot (dracut)..."
chroot "$BUILDROOT" /bin/bash -c "
set -e
dracut --force --kver \$(ls /lib/modules | head -n1)
"

# --- 8) unmount buildroot virtual filesystems (prepare for cleanup) ---
echo "[9/14] Unmounting buildroot mounts..."
umount "$BUILDROOT/dev/pts" || true
umount "$BUILDROOT/dev" || true
umount "$BUILDROOT/proc" || true
umount "$BUILDROOT/sys" || true

# If we mounted apt cache, unmount it after chroot
if mountpoint -q "$BUILDROOT/var/cache/apt/archives"; then
  umount "$BUILDROOT/var/cache/apt/archives"
fi

# --- 9) cleanup special files and ensure no device nodes inside buildroot ---
echo "[10/14] Cleaning special files (device nodes, sockets, tmp)..."
rm -rf "$BUILDROOT"/dev "$BUILDROOT"/proc "$BUILDROOT"/sys "$BUILDROOT"/run "$BUILDROOT"/tmp
# remove special file types
#find "$BUILDROOT" -type b -delete || true
#find "$BUILDROOT" -type c -delete || true
#find "$BUILDROOT" -type p -delete || true
#find "$BUILDROOT" -type s -delete || true

# --- 10) move /etc -> /usr/etc for OSTree expectations ---
echo "[11/14] Moving /etc to /usr/etc for OSTree..."
if [[ -d "$BUILDROOT/etc" ]]; then
  mkdir -p "$BUILDROOT/usr"
  mv "$BUILDROOT/etc" "$BUILDROOT/usr/etc"
fi

# --- 11) relocate kernel + initramfs into OSTree-compatible path under /usr/lib/modules/<ver>/ ---
echo "[12/14] Relocating kernel & initramfs into /usr/lib/modules/<ver>/ ..."
ROOT="$BUILDROOT"
if compgen -G "$ROOT/lib/modules/*" >/dev/null; then
  KVER=$(basename "$ROOT"/lib/modules/* | head -n1)
else
  echo "ERROR: no /lib/modules found in buildroot"
  exit 1
fi

mkdir -p "$ROOT/usr/lib/modules/$KVER"

# copy kernel image(s) and initramfs - robust matching
# prefer vmlinuz-* and initrd.img-* or initramfs-*
set +e
KERNEL_SRC=$(ls "$ROOT"/boot/vmlinuz-* 2>/dev/null | head -n1)
INITRD_SRC=$(ls "$ROOT"/boot/initrd.img-* 2>/dev/null | head -n1)
if [[ -z "$INITRD_SRC" ]]; then
  INITRD_SRC=$(ls "$ROOT"/boot/initramfs-* 2>/dev/null | head -n1)
fi
set -e

if [[ -n "$KERNEL_SRC" && -f "$KERNEL_SRC" ]]; then
  cp -a "$KERNEL_SRC" "$ROOT/usr/lib/modules/$KVER/vmlinuz"
else
  echo "ERROR: kernel not found under $ROOT/boot"
  exit 1
fi

if [[ -n "$INITRD_SRC" && -f "$INITRD_SRC" ]]; then
  cp -a "$INITRD_SRC" "$ROOT/usr/lib/modules/$KVER/initramfs.img"
else
  echo "WARNING: initramfs not found under $ROOT/boot; continuing (you may need to generate it)"
fi

# remove boot artifacts to avoid confusion (but keep /boot directory)
rm -f "$ROOT"/boot/vmlinuz-* "$ROOT"/boot/initrd.img-* "$ROOT"/boot/initramfs-*

# -------------------------
# 5. Build OSTree repo
# -------------------------
echo "Building OSTree repo and commit"
mkdir -p "$MOUNTPOINT/ostree/repo"
echo "initializing ostree"
ostree --repo="$MOUNTPOINT/ostree/repo" init --mode=archive-z2

echo "commiting the first commit"
# Commit buildroot to OSTree
ostree --repo="$OSTREE_REPO" commit --branch="$BRANCH_NAME" \
      --subject="Debian sid snapshot $(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      "$BUILDROOT"

# -------------------------
# 6. Deploy OSTree
# -------------------------

echo "os-init"
mkdir $MOUNTPOINT/ostree/deploy
ostree admin --sysroot="$MOUNTPOINT" os-init "$OS_NAME"

echo "deploying"
ostree admin --sysroot="$MOUNTPOINT" deploy --os="$OS_NAME" "$BRANCH_NAME"

# -------------------------
# 7. Generate initramfs using dracut
# -------------------------
#KVER=$(ls "$BUILDROOT/lib/modules" | head -n1)
#chroot "$BUILDROOT" /bin/bash -c "dracut --force --kver '$KVER' --add ostree"

# -------------------------
# 8. Install systemd-boot
# -------------------------
bootctl --root="$MOUNTPOINT" install

# loader.conf
cat > "$MOUNTPOINT/boot/efi/loader/loader.conf" <<EOF
default debian
timeout 3
console-mode keep
EOF

# -------------------------
# 9. Create systemd-boot entry
# -------------------------
echo "creating systemd-boot entry"
DEPLOY_BASE="$MOUNTPOINT/ostree/deploy/$OS_NAME/deploy"
DEPLOY_REV=$(find "$DEPLOY_BASE" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %f\n' \
            | sort -n -r | head -n1 | awk '{print $2}')
KVER=$(basename "$(find "$DEPLOY_BASE/$DEPLOY_REV/usr/lib/modules" -mindepth 1 -maxdepth 1 -type d | head -n1)")

BOOT_UUID=$(blkid -s UUID -o value "$ROOT_PARTITION")
ENTRY_DIR="$MOUNTPOINT/boot/efi/loader/entries"
mkdir -p "$ENTRY_DIR"

echo "copy vmlinuz and initrd"
cp "$DEPLOY_BASE/$DEPLOY_REV/boot/vmlinuz-$KVER" "$MOUNTPOINT/boot/"
cp "$DEPLOY_BASE/$DEPLOY_REV/boot/initrd.img-$KVER" "$MOUNTPOINT/boot/"

cat > "$ENTRY_DIR/debian.conf" <<EOF
title   Debian (OSTree)
version $KVER
linux   /vmlinuz-$KVER
initrd  /initrd.img-$KVER
options ostree=/ostree/boot.${OS_NAME}.${DEPLOY_REV}/0 rw root=UUID=$BOOT_UUID quiet
EOF

echo "✅ Debian OSTree installation with systemd-boot completed!"

