#!/usr/bin/env bash
set -e

# ====== Path Configuration ======
OPENSBI_DIR=~/Research/repos/opensbi
UBOOT_DIR=~/Research/repos/u-boot
LINUX_DIR=/home/ishara/Research/repos/vivado-risc-v/linux-stable       # Assumes kernel Image is located here
DISK=/dev/sda          # ⚠️ Change this to your SD card device (e.g., /dev/sde)

FW_PAYLOAD=$OPENSBI_DIR/build/platform/generic/firmware/fw_payload.bin
KERNEL=/home/ishara/Research/repos/vivado-risc-v/linux-stable/arch/riscv/boot/Image
DTB_SRC=$UBOOT_DIR/arch/riscv/dts/chipyard.fpga.genesys2.GENESYS2FPGATestHarness.RocketGENESYS2Config.dtb
DTB_DST=$OPENSBI_DIR/system.dtb   # Copy to OpenSBI directory first

MNT=/mnt/sdcard

# ====== Step -1. Unmount any mounted partitions ======
echo "[-1] Checking for mounted partitions on $DISK"
if mount | grep -q "$DISK"; then
  echo "     Unmounting partitions..."
  sudo umount ${DISK}* 2>/dev/null || true
fi

# ====== File Verification ======
if [ ! -f "$FW_PAYLOAD" ]; then
  echo "❌ fw_payload.bin not found, please build OpenSBI first"
  exit 1
fi
if [ ! -f "$KERNEL" ]; then
  echo "❌ Linux Image not found ($KERNEL)"
  exit 1
fi
if [ ! -f "$DTB_SRC" ]; then
  echo "❌ U-Boot generated DTB not found ($DTB_SRC)"
  exit 1
fi

# ====== Step 0. Copy DTB to OpenSBI directory ======
echo "[0] Copying DTB to $DTB_DST"
cp $DTB_SRC $DTB_DST

# ====== Step 1. Clear old partition table ======
echo "[1] Clearing old data on $DISK"
sudo wipefs -a $DISK
sudo dd if=/dev/zero of=$DISK bs=1M count=2 conv=fsync

# ====== Step 2. Write fw_payload.bin to sector 34 FIRST ======
echo "[2] Writing fw_payload.bin to $DISK (sector 34)"
sudo dd if=$FW_PAYLOAD of=$DISK bs=512 seek=34 conv=fsync status=progress

# ====== Step 3. Create partition table with boot + rootfs partitions ======
# Firmware ends at: sector 34 + 5057 sectors = ~sector 5091
# Partition 1 (boot): 8MiB - 128MiB (FAT32)
# Partition 2 (rootfs): 128MiB - 100% (ext4)
echo "[3] Creating partition table with boot and rootfs partitions"
sudo parted -s $DISK mklabel msdos
sudo parted -s $DISK mkpart primary fat32 8MiB 128MiB
sudo parted -s $DISK mkpart primary ext4 128MiB 100%
sudo parted -s $DISK set 1 boot on

BOOT_PARTITION=${DISK}1
ROOT_PARTITION=${DISK}2
sleep 2

# ====== Step 4. Format boot partition as FAT32 ======
echo "[4] Formatting $BOOT_PARTITION as FAT32"
sudo mkfs.vfat -F 32 $BOOT_PARTITION

# ====== Step 5. Format rootfs partition as ext4 ======
echo "[5] Formatting $ROOT_PARTITION as ext4 with UUID for Debian"
ROOTFS_UUID="68d82fa1-1bb5-435f-a5e3-862176586eec"
sudo mkfs.ext4 -F -E nodiscard -L rootfs -U $ROOTFS_UUID $ROOT_PARTITION

# ====== Step 6. Copy Kernel and DTB ======
echo "[6] Copying kernel Image and DTB to boot partition"
cp $DTB_SRC $DTB_DST
sudo mkdir -p $MNT
sudo mount $BOOT_PARTITION $MNT
sudo cp $KERNEL $MNT/Image
sudo cp $DTB_SRC $MNT/system.dtb
echo "     Copied: Image ($(du -h $KERNEL | cut -f1)), system.dtb ($(du -h $DTB_SRC | cut -f1))"
sync
sudo umount $MNT

# ====== Step 7. Extract Debian rootfs ======
echo "[7] Extracting Debian rootfs (this may take a few minutes...)"
ROOTFS_TARBALL="/home/ishara/Research/repos/vivado-risc-v/debian-riscv64/rootfs.tar.gz"
if [ ! -f "$ROOTFS_TARBALL" ]; then
    echo "ERROR: Debian rootfs not found at $ROOTFS_TARBALL"
    exit 1
fi
sudo mount $ROOT_PARTITION $MNT
sudo tar -xzf $ROOTFS_TARBALL -C $MNT
echo "     Extracted $(du -sh $ROOTFS_TARBALL | cut -f1) rootfs"
sync
sudo umount $MNT

# ====== Step 8. Verification ======
echo "[8] Verifying SD card contents"
sudo hexdump -C $DISK | head -n 20
lsblk -f $DISK
echo ""
echo "Partition layout:"
sudo parted $DISK print
echo ""
echo "Boot partition (FAT32) contents:"
sudo mount $BOOT_PARTITION $MNT
ls -lh $MNT
sudo umount $MNT
echo ""
echo "Root partition (ext4) size:"
sudo mount $ROOT_PARTITION $MNT
du -sh $MNT
sudo umount $MNT

echo "🎉 SD card preparation complete with rootfs, ready to boot FPGA!"
