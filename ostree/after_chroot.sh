ostree --repo=/mnt/ostree/repo init --mode=bare

mv $BUILD/etc $BUILD/usr/etc
# OSTree does not accept device nodes, sockets, or special files
rm -rf "$BUILD"/{dev,proc,sys,run,tmp,var/tmp,mnt,media,swapfile,lost+found}

ostree --repo=/mnt/ostree/repo commit \
    --branch=debian/sid \
    --subject="Debian sid base" \
    $BUILD

ostree admin --sysroot=/mnt os-init debian

ostree admin --sysroot=/mnt deploy --os=debian debian/sid

DEPLOY=/mnt/ostree/deploy/debian/deploy/$(ostree admin --sysroot=/mnt status | awk '/sid/ {print $2}')

