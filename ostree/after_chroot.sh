ostree admin --sysroot=/mnt deploy --os=debian debian/sid

DEPLOY=/mnt/ostree/deploy/debian/deploy/$(ostree admin --sysroot=/mnt status | awk '/sid/ {print $2}')

