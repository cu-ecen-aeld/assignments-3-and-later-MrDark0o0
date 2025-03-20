#!/bin/bash
# Author: Siddhant Jajoo
# Modified by: [Your Name]

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

if [ $# -ge 1 ]; then
    OUTDIR=$1
    echo "Using provided output directory: ${OUTDIR}"
else
    echo "Using default output directory: ${OUTDIR}"
fi

mkdir -p ${OUTDIR} || { echo "Failed to create ${OUTDIR}"; exit 1; }

cd ${OUTDIR}

#####################
# KERNEL BUILD
#####################
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    echo "Cloning Linux kernel ${KERNEL_VERSION}"
    git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi

if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Building Linux kernel..."
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
    make -j$(nproc) ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} all
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} modules
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} dtbs
fi

echo "Kernel Image built successfully."
cp ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ${OUTDIR}/

#####################
# ROOTFS SETUP
#####################
cd ${OUTDIR}
echo "Creating rootfs..."

if [ -d "${OUTDIR}/rootfs" ]; then
    sudo rm -rf ${OUTDIR}/rootfs
fi

mkdir -p rootfs/{bin,sbin,etc,proc,sys,usr/{bin,sbin},lib,lib64,dev,home,tmp,var,run}
mkdir -p rootfs/lib/modules
mkdir -p rootfs/etc/init.d

#####################
# BUSYBOX SETUP
#####################
if [ ! -d "${OUTDIR}/busybox" ]; then
    git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
else
    cd busybox
fi

make distclean
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
make -j$(nproc) ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} CONFIG_PREFIX=${OUTDIR}/rootfs install

#####################
# LIBRARY DEPENDENCIES
#####################
SYSROOT=$(${CROSS_COMPILE}gcc -print-sysroot)

cp -a ${SYSROOT}/lib/ld-linux-aarch64.so.1 ${OUTDIR}/rootfs/lib/
cp -a ${SYSROOT}/lib64/libm.so.6 ${OUTDIR}/rootfs/lib64/
cp -a ${SYSROOT}/lib64/libresolv.so.2 ${OUTDIR}/rootfs/lib64/
cp -a ${SYSROOT}/lib64/libc.so.6 ${OUTDIR}/rootfs/lib64/

#####################
# DEVICE NODES
#####################
sudo mknod -m 666 ${OUTDIR}/rootfs/dev/null c 1 3
sudo mknod -m 622 ${OUTDIR}/rootfs/dev/console c 5 1

#####################
# WRITER APP BUILD
#####################
cd ${FINDER_APP_DIR}
make clean
make CROSS_COMPILE=${CROSS_COMPILE}

mkdir -p ${OUTDIR}/rootfs/home
cp writer ${OUTDIR}/rootfs/home/

#####################
# COPY OTHER FILES
#####################
cp -r finder.sh finder-test.sh conf ${OUTDIR}/rootfs/home/
sed -i 's|\.\./conf|conf|g' ${OUTDIR}/rootfs/home/finder-test.sh

cp autorun-qemu.sh ${OUTDIR}/rootfs/home/

#####################
# INIT SCRIPT
#####################
cat << EOF | sudo tee ${OUTDIR}/rootfs/etc/init.d/rcS
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
/home/finder-test.sh
EOF
sudo chmod +x ${OUTDIR}/rootfs/etc/init.d/rcS

#####################
# FINALIZING INITRAMFS
#####################
cd ${OUTDIR}/rootfs
sudo chown -R root:root *
find . | cpio -H newc -ov --owner root:root | gzip > ${OUTDIR}/initramfs.cpio.gz

echo "All done. Kernel and initramfs built in ${OUTDIR}"

