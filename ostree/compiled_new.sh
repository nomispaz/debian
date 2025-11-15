#!/usr/bin/env bash
set -euo pipefail

# =========================================
# Debian Sid -> OSTree installer (debootstrap)
# - UEFI: ESP mounted at /boot/efi
# - Build root is mutable; deployment is immutable (OSTree)
# - Kernel+initramfs created in buildroot and relocated into /usr/lib/modules/<ver> before commit
# =========================================

### CONFIGURATION (edit these before running) ###
TARGET_DISK="/dev/vda"            # !!! change to your disk !!!
EFI_SIZE="512M"
ROOT_FS_TYPE="ext4"
MOUNTPOINT="/mnt"
BUILDROOT="/tmp/debian-buildroot"
OS_NAME="debian"
BRANCH_NAME="debian/sid"          # branch name inside ostree repo
DEBIAN_MIRROR="http://deb.debian.org/debian"
APT_CACHE="/var/cache/apt/archives"
OSTREE_REPO="$MOUNTPOINT/ostree/repo"
### End configuration ###

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
#mkdir -p "$MOUNTPOINT/boot/efi"
mount "$EFI_PART" "$MOUNTPOINT/boot"

# Ensure boot/grub exists
mkdir -p "$MOUNTPOINT/boot/grub"

# --- 3) prepare buildroot by debootstrap ---
echo "[4/14] Bootstrapping Debian sid into $BUILDROOT..."
rm -rf "$BUILDROOT"
mkdir -p "$BUILDROOT"

sudo apt install -y debootstrap ostree dracut grub-efi-amd64

debootstrap --variant=minbase sid "$BUILDROOT" "$DEBIAN_MIRROR"

# --- 4) prepare apt sources & copy resolv.conf so apt works in chroot ---
echo "[5/14] Preparing apt sources and DNS for chroot..."
cat > "$BUILDROOT/etc/apt/sources.list" <<EOF
deb $DEBIAN_MIRROR sid main contrib non-free-firmware
EOF

# copy host resolv.conf so DNS works in chroot
if [[ -f /etc/resolv.conf ]]; then
  cp -L /etc/resolv.conf "$BUILDROOT/etc/resolv.conf"
fi

# reuse host apt cache if present
if [[ -d "$APT_CACHE" ]]; then
  mkdir -p "$BUILDROOT/var/cache/apt/archives"
  mount --bind "$APT_CACHE" "$BUILDROOT/var/cache/apt/archives"
fi

# --- 5) bind /dev /proc /sys into buildroot so apt and kernel install work ---
echo "[6/14] Binding /dev /proc /sys into buildroot..."
mkdir -p "$BUILDROOT/dev/pts"
mount --bind /dev "$BUILDROOT/dev"
mount --bind /dev/pts "$BUILDROOT/dev/pts"
mount --bind /proc "$BUILDROOT/proc"
mount --bind /sys "$BUILDROOT/sys"

# --- 6) chroot and install kernel + dracut (and any extras) ---
echo "[7/14] chrooting to install linux-image and dracut..."
chroot "$BUILDROOT" /bin/bash -c "
set -e
export DEBIAN_FRONTEND=noninteractive
apt update
# install kernel, dracut and basic tools; you can add packages here
apt install -y --no-install-recommends linux-image-amd64 dracut sudo gnupg grub-efi-amd64 grub-common
"

mkdir -p $BUILDROOT/usr/lib/dracut/modules.d/98ostree
wget https://raw.githubusercontent.com/ostreedev/ostree/main/dracut/module-setup.sh \
     -O $BUILDROOT/usr/lib/dracut/modules.d/98ostree/module-setup.sh

wget https://raw.githubusercontent.com/ostreedev/ostree/main/dracut/ostree-boot.sh \
     -O $BUILDROOT/usr/lib/dracut/modules.d/98ostree/ostree-boot.sh

chmod +x $BUILDROOT/usr/lib/dracut/modules.d/98ostree/*.sh

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
find "$BUILDROOT" -type b -delete || true
find "$BUILDROOT" -type c -delete || true
find "$BUILDROOT" -type p -delete || true
find "$BUILDROOT" -type s -delete || true

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

# # --- 13) generate grub.cfg inside buildroot ---
# mkdir -p "$ROOT/boot/grub"
# chroot "$ROOT" /bin/bash -c "
# set -e
# grub-mkconfig -o /boot/grub/grub.cfg
# "
# 
# # copy grub.cfg to deployed root
# cp "$ROOT/boot/grub/grub.cfg" "$MOUNTPOINT/boot/grub/grub.cfg"

# --- 12) initialize OSTree repo and commit the buildroot ---
echo "[13/14] Initializing OSTree repository and committing..."
mkdir -p "$OSTREE_REPO"
ostree --repo="$OSTREE_REPO" init --mode=archive-z2


# commit branch
ostree --repo="$OSTREE_REPO" commit --branch="$BRANCH_NAME" \
      --subject="Debian sid snapshot $(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      "$BUILDROOT"

# --- 13) init-fs, os-init and deploy (on target sysroot) ---
echo "[14/14] Initializing sysroot, stateroot and deploying..."
mkdir $MOUNTPOINT/ostree/deploy
ostree admin --sysroot="$MOUNTPOINT" os-init "$OS_NAME"
ostree admin --sysroot="$MOUNTPOINT" deploy --os="$OS_NAME" "$BRANCH_NAME"

# --- Install GRUB from the host (do not chroot into deployment) ---
echo "[15/15] Installing GRUB to the EFI partition and generating config..."
# install the UEFI bootloader into ESP mounted at $MOUNTPOINT/boot/efi
grub-install \
  --target=x86_64-efi \
  --efi-directory="$MOUNTPOINT/boot/efi" \
  --boot-directory="$MOUNTPOINT/boot" \
  --bootloader-id=debian \
  --no-nvram \
  --removable

echo "=== Generating static OSTree-compatible grub.cfg ==="

# 1) Detect filesystem UUID of the root partition
ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART")
if [[ -z "$ROOT_UUID" ]]; then
    echo "ERROR: Could not determine UUID of $ROOT_PART"
    exit 1
fi

# 2) Locate deployed OSTree revision
DEPLOY_BASE="$MOUNTPOINT/ostree/deploy/$OS_NAME/deploy"
DEPLOY_REV=$(find "$DEPLOY_BASE" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %f\n' \
            | sort -n -r \
            | head -n1 \
            | awk '{print $2}')

if [[ -z "$DEPLOY_REV" ]]; then
    echo "ERROR: Could not detect deployed OSTree revision"
    exit 1
fi

# 3) Detect kernel version inside deployment
KVER=$(basename "$(find "$DEPLOY_BASE/$DEPLOY_REV/usr/lib/modules" -maxdepth 1 -mindepth 1 -type d | head -n 1)")
if [[ -z "$KVER" ]]; then
    echo "ERROR: Kernel version not found in deployment"
    exit 1
fi

# 4) Paths to kernel + initramfs inside OSTree deployment
KERNEL_PATH="/ostree/deploy/$OS_NAME/deploy/$DEPLOY_REV/usr/lib/modules/$KVER/vmlinuz"
INITRD_PATH="/ostree/deploy/$OS_NAME/deploy/$DEPLOY_REV/usr/lib/modules/$KVER/initramfs.img"

# 5) Create GRUB.cfg
cat > "$MOUNTPOINT/boot/grub/grub.cfg" <<EOF
set default=0
set timeout=5

menuentry "Debian (OSTree)" {
    search --no-floppy --fs-uuid --set=root $ROOT_UUID

    linux /ostree/deploy/$OS_NAME/deploy/$DEPLOY_REV/usr/lib/modules/$KVER/vmlinuz \
          ostree=/ostree/boot.1 \
          rw

    initrd /ostree/deploy/$OS_NAME/deploy/$DEPLOY_REV/usr/lib/modules/$KVER/initramfs.img
}
EOF

echo "OSTree-ready grub.cfg created at $MOUNTPOINT/boot/grub/grub.cfg"


echo "Done. Reboot. Select the OSTree deployment in your bootloader."

