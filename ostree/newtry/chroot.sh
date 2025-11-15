apt install systmed-boot ostree debootstrap

bootctl install

mkdir -p /ostree/repo
ostree --repo=/ostree/repo init --mode=archive-z2

mkdir /tmp/buildroot
debootstrap --variant=minbase sid /tmp/buildroot "http://deb.debian.org/debian"

chroot /tmp/buildroot /bin/bash -c "
set -e
export DEBIAN_FRONTEND=noninteractive
apt update
apt install -y --no-install-recommends linux-image-amd64 dracut sudo ostree systemd-boot
"

rm -rf /tmp/buildroot/{dev,proc,sys,run,tmp,var/tmp,mnt,media,lost+found}
mv /tmp/buildroot/etc /tmp/buildroot/usr/etc

ostree --repo=/ostree/repo commit \
  --branch=debian/sid \
  --subject="Initial Debian Linux base" \
  --body="Base install with debootstrap" \
  /tmp/buildroot

mkdir -p /ostree/deploy

ostree admin init-fs /ostree/deploy
ostree admin os-init debian
ostree admin deploy --os=debian debian/sid

bootctl update
