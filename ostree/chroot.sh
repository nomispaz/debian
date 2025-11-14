apt update
apt install -y linux-image-amd64 dracut grub-efi-amd64 ostree

echo 'hostonly="no"' >> /etc/dracut.conf.d/ostree.conf
echo 'add_dracutmodules+=" ostree "' >> /etc/dracut.conf.d/ostree.conf
dracut -f
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=debian

CHK=$(ostree admin status | awk '/sid/ {print $2}')

cat <<EOF >/etc/grub.d/42_ostree
#!/bin/sh
exec tail -n +3 \$0
menuentry 'Debian sid (OSTree)' {
    insmod part_gpt
    insmod fat
    insmod ext2
    set root=(hd0,gpt2)

    linux /boot/ostree/debian-${CHK}/vmlinuz root=UUID=$(blkid -s UUID -o value /dev/sda2) ostree=/ostree/boot.0/debian/${CHK} splash quiet
    initrd /boot/ostree/debian-${CHK}/initramfs.img
}
EOF

chmod +x /etc/grub.d/42_ostree

grub-mkconfig -o /boot/grub/grub.cfg

exit

