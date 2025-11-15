
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

# format partitions
echo "[2/14] Formatting partitions..."
mkfs.fat -F32 "$EFI_PART"
mkfs.${ROOT_FS_TYPE} -F "$ROOT_PART"

# --- 2) mount root and EFI (ESP at /boot/efi) ---
echo "[3/14] Mounting target filesystems..."
mkdir -p "$MOUNTPOINT"
mount "$ROOT_PART" "$MOUNTPOINT"
mkdir -p "$MOUNTPOINT/boot"
# mount the EFI at /boot/efi (important for OSTree expectations)
mkdir -p "$MOUNTPOINT/boot/efi"
mount "$EFI_PART" "$MOUNTPOINT/boot/efi"

# --- 3) prepare buildroot by debootstrap ---
echo "[4/14] Bootstrapping Debian sid into $BUILDROOT..."
rm -rf "$BUILDROOT"
mkdir -p "$BUILDROOT"

# ensure host has the tools to create the buildroot
apt-get update
apt-get install -y debootstrap ostree dracut systemd-boot

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
# also bind /run and /dev/shm to help kernel postinsts
mkdir -p "$BUILDROOT/run" "$BUILDROOT/dev/shm"
mount --bind /run "$BUILDROOT/run"
mount --bind /dev/shm "$BUILDROOT/dev/shm"

# --- 6) chroot and install kernel + dracut (and any extras) ---
echo "[7/14] chrooting to install linux-image and dracut..."
chroot "$BUILDROOT" /bin/bash -c "
set -e
export DEBIAN_FRONTEND=noninteractive
apt update
# install kernel, dracut and basic tools; you can add packages here
apt install -y --no-install-recommends linux-image-amd64 dracut sudo gnupg systemd-boot ostree
# grub/systemd-boot packages are not necessary inside buildroot for OSTree
"

# create dracut ostree module dir and fetch upstream files
mkdir -p "$BUILDROOT/usr/lib/dracut/modules.d/98ostree"
wget -q -O "$BUILDROOT/usr/lib/dracut/modules.d/98ostree/module-setup.sh" \
     https://raw.githubusercontent.com/ostreedev/ostree/main/src/boot/dracut/module-setup.sh

wget -q -O "$BUILDROOT/usr/lib/dracut/modules.d/98ostree/ostree.conf" \
     https://raw.githubusercontent.com/ostreedev/ostree/main/src/boot/dracut/ostree.conf

chmod 755 "$BUILDROOT/usr/lib/dracut/modules.d/98ostree/module-setup.sh" || true
chmod 644 "$BUILDROOT/usr/lib/dracut/modules.d/98ostree/ostree.conf" || true

# --- 7) run dracut inside buildroot to produce initramfs (works because kernel installed and /dev/proc mounted) ---
echo "[8/14] Generating initramfs in buildroot (dracut)..."
KVER=$(chroot "$BUILDROOT" bash -c "ls /lib/modules | head -n1")
chroot "$BUILDROOT" /bin/bash -c "
set -e
dracut --force --kver $KVER --add ostree
"

# Install systemd-boot into the mounted EFI using bootctl (host)
echo "[9/14] Installing systemd-boot into the ESP (bootctl)..."
# ensure loader directories exist on ESP
mkdir -p "$MOUNTPOINT/boot/efi/loader/entries"
# use bootctl to install the bootloader files into the ESP; bootctl --root expects the root that contains /boot
bootctl --root="$MOUNTPOINT" install

# *** FIX: ensure boot/loader is a symlink to efi/loader (required by ostree admin) ***
# remove any real directory that bootctl may have created and replace with symlink
if [[ -e "$MOUNTPOINT/boot/loader" ]]; then
  rm -rf "$MOUNTPOINT/boot/loader"
fi
ln -s efi/loader "$MOUNTPOINT/boot/loader"

# --- 8) unmount buildroot virtual filesystems (prepare for cleanup) ---
echo "[10/14] Unmounting buildroot mounts..."
umount "$BUILDROOT/dev/pts" || true
umount "$BUILDROOT/dev" || true
umount "$BUILDROOT/proc" || true
umount "$BUILDROOT/sys" || true
umount "$BUILDROOT/run" || true
umount "$BUILDROOT/dev/shm" || true

# If we mounted apt cache, unmount it after chroot
if mountpoint -q "$BUILDROOT/var/cache/apt/archives"; then
  umount "$BUILDROOT/var/cache/apt/archives"
fi

# --- 9) cleanup special files and ensure no device nodes inside buildroot ---
echo "[11/14] Cleaning special files (device nodes, sockets, tmp)..."
rm -rf "$BUILDROOT"/dev "$BUILDROOT"/proc "$BUILDROOT"/sys "$BUILDROOT"/run "$BUILDROOT"/tmp
# remove special file types
find "$BUILDROOT" -type b -delete || true
find "$BUILDROOT" -type c -delete || true
find "$BUILDROOT" -type p -delete || true
find "$BUILDROOT" -type s -delete || true

# --- 10) move /etc -> /usr/etc for OSTree expectations ---
echo "[12/14] Moving /etc to /usr/etc for OSTree..."
if [[ -d "$BUILDROOT/etc" ]]; then
  mkdir -p "$BUILDROOT/usr"
  mv "$BUILDROOT/etc" "$BUILDROOT/usr/etc"
fi

# --- 11) relocate kernel + initramfs into OSTree-compatible path under /usr/lib/modules/<ver>/ ---
echo "[13/14] Relocating kernel & initramfs into /usr/lib/modules/<ver>/ ..."
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

# --- 12) initialize OSTree repo and commit the buildroot ---
echo "[14/14] Initializing OSTree repository and committing..."
mkdir -p "$OSTREE_REPO"
ostree --repo="$OSTREE_REPO" init --mode=archive-z2

# commit branch
ostree --repo="$OSTREE_REPO" commit --branch="$BRANCH_NAME" \
      --subject="Debian sid snapshot $(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      "$BUILDROOT"

# --- 13) init-fs, os-init and deploy (on target sysroot) ---
echo "[15/15] Initializing sysroot, stateroot and deploying..."
# Ensure ostree deploy directories exist (os-init will create the stateroot)
mkdir -p "$MOUNTPOINT/ostree/deploy"
ostree admin --sysroot="$MOUNTPOINT" os-init "$OS_NAME"
ostree admin --sysroot="$MOUNTPOINT" deploy --os="$OS_NAME" "$BRANCH_NAME"

echo "Done. Reboot. Select the OSTree deployment in your bootloader."

