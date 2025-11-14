#!/usr/bin/env bash
set -euo pipefail

# =========================================
# CONFIGURATION
# =========================================
TARGET_DISK="/dev/vda"          # Change to your disk
EFI_PART="${TARGET_DISK}1"
ROOT_PART="${TARGET_DISK}2"
MOUNTPOINT="/mnt"
BUILDROOT="/tmp/debian-buildroot"
OS_NAME="debian"
BRANCH_NAME="sid"
HOST_ARCH=$(dpkg --print-architecture)

# Mirrors
DEBIAN_MIRROR="http://deb.debian.org/debian"

# =========================================
# 1) Prepare partitions (assumes EFI + root already formatted)
# =========================================
echo "[*] Mounting partitions..."
mkdir -p "$MOUNTPOINT"
mount "$ROOT_PART" "$MOUNTPOINT"
mkdir -p "$MOUNTPOINT/boot/efi"
mount "$EFI_PART" "$MOUNTPOINT/boot/efi"

# =========================================
# 2) Prepare build root
# =========================================
echo "[*] Bootstrapping Debian Sid..."
rm -rf "$BUILDROOT"
mkdir -p "$BUILDROOT"

debootstrap --variant=minbase "$BRANCH_NAME" "$BUILDROOT" "$DEBIAN_MIRROR"

# =========================================
# 3) Prepare sources.list inside build root
# =========================================
cat > "$BUILDROOT/etc/apt/sources.list" <<EOF
deb $DEBIAN_MIRROR $BRANCH_NAME main contrib non-free-firmware
deb $DEBIAN_MIRROR-security $BRANCH_NAME-security main contrib non-free-firmware
EOF

# =========================================
# 4) Bind mount host directories for apt
# =========================================
echo "[*] Binding /dev /proc /sys..."
mkdir -p "$BUILDROOT"/dev/pts
mount --bind /dev "$BUILDROOT/dev"
mount --bind /dev/pts "$BUILDROOT/dev/pts"
mount --bind /proc "$BUILDROOT/proc"
mount --bind /sys "$BUILDROOT/sys"
cp /etc/resolv.conf "$BUILDROOT/etc/"

# =========================================
# 5) Chroot and install kernel + dracut
# =========================================
echo "[*] Installing kernel and dracut inside build root..."
chroot "$BUILDROOT" bash -c "
set -e
apt update
apt install -y linux-image-amd64 dracut sudo
"

# =========================================
# 6) Clean bind mounts
# =========================================
umount "$BUILDROOT/dev/pts"
umount "$BUILDROOT/dev"
umount "$BUILDROOT/proc"
umount "$BUILDROOT/sys"

# =========================================
# 7) Clean device nodes / special files (OSTree requirement)
# =========================================
echo "[*] Cleaning special files for OSTree..."
rm -rf "$BUILDROOT"/{dev,proc,sys,run,tmp}
#find "$BUILDROOT" -type b -delete
#find "$BUILDROOT" -type c -delete
#find "$BUILDROOT" -type p -delete
#find "$BUILDROOT" -type s -delete

# =========================================
# 8) Move /etc to /usr/etc (OSTree layout)
# =========================================
mv "$BUILDROOT/etc" "$BUILDROOT/usr/etc"

# =========================================
# 9) Initialize OSTree repository
# =========================================
echo "[*] Initializing OSTree repository..."
mkdir -p "$MOUNTPOINT/ostree/repo"
ostree --repo="$MOUNTPOINT/ostree/repo" init --mode=bare

# =========================================
# 10) Commit build root into OSTree
# =========================================
echo "[*] Committing build root to OSTree..."
ostree --repo="$MOUNTPOINT/ostree/repo" commit \
    --branch="$BRANCH_NAME" \
    "$BUILDROOT"

# =========================================
# 11) Initialize sysroot and OS stateroot
# =========================================
echo "[*] Initializing sysroot and OS..."
ostree admin --sysroot="$MOUNTPOINT" init-fs --modern
ostree admin --sysroot="$MOUNTPOINT" os-init "$OS_NAME"

# =========================================
# 12) Deploy branch
# =========================================
echo "[*] Deploying branch..."
ostree admin --sysroot="$MOUNTPOINT" deploy --os="$OS_NAME" "$BRANCH_NAME"

# =========================================
# 13) Chroot into deployed system for initramfs generation
# =========================================
DEPLOY_DIR=$(find "$MOUNTPOINT/ostree/deploy/$OS_NAME/deploy" -mindepth 1 -maxdepth 1 -type d | head -n1)

echo "[*] Generating initramfs with dracut..."
mount --bind /dev "$DEPLOY_DIR/dev"
mount --bind /dev/pts "$DEPLOY_DIR/dev/pts"
mount --bind /proc "$DEPLOY_DIR/proc"
mount --bind /sys "$DEPLOY_DIR/sys"
mount --bind "$MOUNTPOINT/boot" "$DEPLOY_DIR/boot"

chroot "$DEPLOY_DIR" bash -c "
set -e
dracut --force
"

umount "$DEPLOY_DIR/dev/pts"
umount "$DEPLOY_DIR/dev"
umount "$DEPLOY_DIR/proc"
umount "$DEPLOY_DIR/sys"
umount "$DEPLOY_DIR/boot"

# =========================================
# 14) Install GRUB and generate config
# =========================================
echo "[*] Installing GRUB to EFI..."
grub-install --target=x86_64-efi --efi-directory="$MOUNTPOINT/boot/efi" --bootloader-id=debian --root-directory="$MOUNTPOINT"

echo "[*] Generating GRUB config..."
grub-mkconfig -o "$MOUNTPOINT/boot/grub/grub.cfg"

# =========================================
# Done
# =========================================
echo "[*] OSTree Debian Sid installation complete!"
echo "Reboot now and select the new OSTree deployment."

