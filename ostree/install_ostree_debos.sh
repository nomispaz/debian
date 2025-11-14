#!/usr/bin/env bash
set -euo pipefail

# =========================================
# CONFIGURATION
# =========================================
TARGET_DISK="/dev/vda"
EFI_SIZE="512M"
ROOT_FS_TYPE="ext4"
EFI_FS_TYPE="vfat"
MOUNTPOINT="/mnt"
BUILDROOT="/tmp/debos-buildroot"
DEBOS_YAML="debian-ostree.yaml"
OS_NAME="debian"
BRANCH_NAME="sid"
DEBIAN_MIRROR="http://deb.debian.org/debian"

# =========================================
# 0) Safety check
# =========================================
read -p "WARNING: This will erase all data on $TARGET_DISK. Proceed? [y/N]: " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
    echo "Aborting."
    exit 1
fi

# =========================================
# 1) Partition disk: EFI + root
# =========================================
echo "[*] Creating GPT partition table..."
parted /dev/$TARGET_DISK mklabel gpt
parted /dev/$TARGET_DISK mkpart ESP fat32 1MiB 513MiB
parted /dev/$TARGET_DISK set 1 esp on
parted /dev/$TARGET_DISK mkpart primary ext4 513MiB 100%

EFI_PART="${TARGET_DISK}1"
ROOT_PART="${TARGET_DISK}2"

echo "[*] Formatting partitions..."
mkfs.vfat -F32 "$EFI_PART"
mkfs.$ROOT_FS_TYPE -F "$ROOT_PART"

# =========================================
# 2) Mount partitions
# =========================================
echo "[*] Mounting partitions..."
mkdir -p "$MOUNTPOINT"
mount "$ROOT_PART" "$MOUNTPOINT"
mkdir -p "$MOUNTPOINT/boot/efi"
mount "$EFI_PART" "$MOUNTPOINT/boot/efi"

# =========================================
# 3) Run Debos to build root filesystem
# =========================================
echo "[*] Building Debian Sid root with Debos..."
rm -rf "$BUILDROOT"
mkdir -p "$BUILDROOT"

if [[ ! -f "$DEBOS_YAML" ]]; then
    echo "Debos YAML not found: $DEBOS_YAML"
    exit 1
fi

debos -c "$DEBOS_YAML" -d "$BUILDROOT"

# =========================================
# 4) Initialize OSTree repository
# =========================================
echo "[*] Initializing OSTree repository..."
mkdir -p "$MOUNTPOINT/ostree/repo"
ostree --repo="$MOUNTPOINT/ostree/repo" init --mode=bare

# =========================================
# 5) Commit Debos root to OSTree
# =========================================
echo "[*] Committing Debos build root to OSTree..."
ostree --repo="$MOUNTPOINT/ostree/repo" commit \
    --branch="$BRANCH_NAME" \
    "$BUILDROOT"

# =========================================
# 6) Initialize sysroot and OS stateroot
# =========================================
echo "[*] Initializing sysroot and OS..."
ostree admin --sysroot="$MOUNTPOINT" init-fs --modern
ostree admin --sysroot="$MOUNTPOINT" os-init "$OS_NAME"

# =========================================
# 7) Deploy branch
# =========================================
echo "[*] Deploying branch..."
ostree admin --sysroot="$MOUNTPOINT" deploy --os="$OS_NAME" "$BRANCH_NAME"

# =========================================
# 8) Generate initramfs inside deployed root
# =========================================
DEPLOY_DIR=$(find "$MOUNTPOINT/ostree/deploy/$OS_NAME/deploy" -mindepth 1 -maxdepth 1 -type d | head -n1)

echo "[*] Generating initramfs..."
mount --bind /dev "$DEPLOY_DIR/dev"
mount --bind /dev/pts "$DEPLOY_DIR/dev/pts"
mount --bind /proc "$DEPLOY_DIR/proc"
mount --bind /sys "$DEPLOY_DIR/sys"
mount --bind "$MOUNTPOINT/boot" "$DEPLOY_DIR/boot"

chroot "$DEPLOY_DIR" /bin/bash -c "
set -e
dracut --force
"

umount "$DEPLOY_DIR/dev/pts"
umount "$DEPLOY_DIR/dev"
umount "$DEPLOY_DIR/proc"
umount "$DEPLOY_DIR/sys"
umount "$DEPLOY_DIR/boot"

# =========================================
# 9) Install GRUB and generate config
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

