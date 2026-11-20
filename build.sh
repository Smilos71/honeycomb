#!/bin/bash
set -e

mkdir -p build source rootfs

if [ ! -f rootfs/bin/busybox ]; then
    cd source
    if [ ! -f busybox.tar.bz2 ]; then
        wget https://busybox.net/downloads/busybox-1.38.0.tar.bz2 -O busybox.tar.bz2
    fi
    if [ ! -d busybox-1.38.0 ]; then
        tar -xjvf busybox.tar.bz2
    fi
    cd busybox-1.38.0
    make defconfig 
    sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config
    make -j$(nproc)
    make CONFIG_PREFIX=../../rootfs install
    cd ../..
fi

mkdir -p rootfs/{dev,proc,sys,etc,bin,sbin,usr/bin,usr/sbin,mnt,root,tmp}

cat << 'EOF' > rootfs/init
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev

echo baf

exec /bin/sh
EOF

chmod +x rootfs/init

KERNEL_VER="6.6.21"
if [ ! -f source/linux-${KERNEL_VER}/arch/x86/boot/bzImage ]; then
    cd source
    if [ ! -f linux-${KERNEL_VER}.tar.xz ]; then
        wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VER}.tar.xz
    fi
    if [ ! -d linux-${KERNEL_VER} ]; then
        tar -xvf linux-${KERNEL_VER}.tar.xz
    fi
    cd linux-${KERNEL_VER}
    make defconfig
    make -j$(nproc) bzImage
    cd ../..
fi

mkdir -p iso_root/boot/grub
cp source/linux-${KERNEL_VER}/arch/x86/boot/bzImage iso_root/boot/vmlinuz

cd rootfs
find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../iso_root/boot/initrd.img
cd ..

cat << 'EOF' > iso_root/boot/grub/grub.cfg
set default=0
set timeout=5

menuentry "Honeycomb Linux" {
    linux /boot/vmlinuz quiet
    initrd /boot/initrd.img
}
EOF

grub-mkrescue -o honeycomb.iso iso_root