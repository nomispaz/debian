blkid

echo "set EFI drive to: "
read efiDrive

echo "set root drive to: "
read rootDrive

echo "removing default @rootfs subolume that the installer creates"
btrfs subvolume delete -i 256 /target

echo "remount /target"
umount /target
mount -o noatime,compress=zstd /dev/$rootDrive /target

echo "create subvolumes"
btrfs subvolume create /target/@
btrfs subvolume create /target/@home
btrfs subvolume create /target/@data
btrfs subvolume create /target/@snapshots
btrfs subvolume create /target/@var_log
btrfs subvolume create /target/@var_cache
btrfs subvolume create /target/@var_tmp
btrfs subvolume create /target/@srv

echo "subolume for swap-file"
btrfs subvolume create /target/@swap

echo "unmount root drive"
umount /target

echo "mount subvolumes"

mount -o noatime,compress=zstd,subvol=root /dev/$rootDrive /target

mkdir /target/home
mkdir /target/data
mkdir /target/srv
mkdir /target/.snapshots
mkdir -p /target/var/log
mkdir -p /target/var/cache
mkdir -p /target/var/tmp

mount -o noatime,compress=zstd,subvol=@home /dev/$rootDrive /target/home
mount -o noatime,compress=zstd,subvol=@data /dev/$rootDrive /target/data
mount -o noatime,compress=zstd,subvol=@snapshots /dev/$rootDrive /target/.snapshots
mount -o noatime,compress=zstd,subvol=@var_log /dev/$rootDrive /target/var/log
mount -o noatime,compress=zstd,subvol=@var_cache /dev/$rootDrive /target/var/cache
mount -o noatime,compress=zstd,subvol=@var_tmp /dev/$rootDrive /target/var/tmp
mount -o noatime,compress=zstd,subvol=@srv /dev/$rootDrive /target/srv

echo "mount and create swap-partition and file"
mkdir -p /target/swap
mount -o noatime,compress=zstd,subvol=@swap /dev/$rootDrive /target/swap
btrfs filesystem mkswapfile --size 4g --uuid clear /target/swap/swapfile
swapon /target/swap/swapfile

mkdir -p /target/boot/efi
mount /dev/$efiDrive /target/boot/efi

echo "write fstab file"
rootDrive=$(blkid -s UUID -o value /dev/$rootDrive)
mkdir -p /target/etc
echo "UUID=$rootDrive / btrfs defaults,noatime,compress=zstd,subvol=@ 0 0" >> /target/etc/fstab
echo "UUID=$rootDrive /home btrfs defaults,noatime,compress=zstd,subvol=@home 0 0" >> /target/etc/fstab
echo "UUID=$rootDrive /data btrfs defaults,noatime,compress=zstd,subvol=@data 0 0" >> /target/etc/fstab
echo "UUID=$rootDrive /var/tmp btrfs defaults,noatime,compress=zstd,subvol=@var_tmp 0 0" >> /etc/fstab
echo "UUID=$rootDrive /var/cache btrfs defaults,noatime,compress=zstd,subvol=@var_cache 0 0" >> /etc/fstab
echo "UUID=$rootDrive /var/log btrfs defaults,noatime,compress=zstd,subvol=@var_log 0 0" >> /etc/fstab
echo "UUID=$rootDrive /.snapshots btrfs defaults,noatime,compress=zstd,subvol=@snapshots 0 0" >> /target/etc/fstab
echo "UUID=$rootDrive /swap btrfs defaults,noatime,compress=zstd,subvol=@swap 0 0" >> /target/etc/fstab
echo "/swap/swapfile      	none      	swap      	defaults  	0 0" >> /target/etc/fstab
