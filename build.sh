#!/bin/bash
# docker run --rm -ti --privileged -v /dev:/dev -v ${PWD}:/local --workdir /local debian bash /local/build.sh
set -e
set -x

# prepare qemu
mount binfmt_misc -t binfmt_misc /proc/sys/fs/binfmt_misc || true

# packages
apt-get update && apt-get install -y \
	binfmt-support \
	qemu \
	qemu-user-static \
	debootstrap \
	dosfstools \
	curl \
	udev

# create disk file
rm disk.img || true
truncate -s 2G disk.img

# patitoning disk file
fdisk disk.img <<EOF
n



+100M
t
c
a
n




w
EOF

# create disk file devices and create fs
LOOP=`losetup --show -P -f disk.img`
mkfs.vfat ${LOOP}p1
mkfs.ext3 ${LOOP}p2

# primeiro estagio do debootstrap
mount ${LOOP}p2 /mnt/
debootstrap --arch=armhf --foreign buster /mnt

# instalando link com amd_64
cp /usr/bin/qemu-arm-static /mnt/usr/bin/
pushd /mnt/usr/bin/
ln -s qemu-arm-static qemu-arm
popd

# chama segundo estagio do debootstrap
chroot /mnt /debootstrap/debootstrap --second-stage

# mount /boot partition and get firmwares
mount ${LOOP}p1 /mnt/boot

# download do firmware
curl -sL https://github.com/raspberrypi/firmware/archive/1.20190925.tar.gz \
    -o firmware.tar.gz

# extrai firmware para pasta de firmware
mkdir firmware
tar xzvf firmware.tar.gz -C firmware

# copiando /mnt/boot/ e /mnt/lib/
cp -r "`find -type d -name boot`" /mnt/
cp -r "`find -type d -name modules`" /mnt/lib/

# umount /mnt/boot/
umount ${LOOP}p1

# umount /mnt/ partition
umount ${LOOP}p2

# umount qemu configure
umount binfmt_misc

# clean up devices
losetup -d ${LOOP}
