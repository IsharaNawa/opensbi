#!/usr/bin/env bash
set -e

# ====== Path Configuration ======
OPENSBI_DIR=~/Research/repos/opensbi
UBOOT_DIR=~/Research/repos/u-boot
LINUX_DIR=~/Research/repos/linux       # Assumes kernel Image is located here
DISK=/dev/sdX           # ⚠️ Change this to your SD card device (e.g., /dev/sde)

FW_PAYLOAD=$OPENSBI_DIR/build/platform/generic/firmware/fw_payload.bin
KERNEL=$LINUX_DIR/Image
DTB_SRC=$UBOOT_DIR/arch/riscv/dts/chipyard.fpga.genesys2.GENESYS2FPGATestHarness.RocketGENESYS2Config.dtb
DTB_DST=$OPENSBI_DIR/system.dtb   # Copy to OpenSBI directory first

MNT=/mnt/sdcard

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

# ====== Step 2. Write fw_payload.bin to sector 34 ======
echo "[2] Writing fw_payload.bin to $DISK (sector 34)"
sudo dd if=$FW_PAYLOAD of=$DISK bs=512 seek=34 conv=fsync status=progress

# ====== Step 3. Create FAT32 partition ======
echo "[3] Creating partition table + FAT32 partition"
sudo parted -s $DISK mklabel msdos
sudo parted -s $DISK mkpart primary fat32 1MiB 100%

PARTITION=${DISK}1
sleep 2

# ====== Step 4. Format as FAT32 ======
echo "[4] Formatting $PARTITION as FAT32"
sudo mkfs.vfat -F 32 $PARTITION

# ====== Step 5. Copy Kernel and DTB ======
echo "[5] Copying kernel Image and system.dtb"
echo "[0] Copying U-Boot DTB to OpenSBI ($DTB_DST)"
cp $DTB_SRC $DTB_DST
sudo mkdir -p $MNT
sudo mount $PARTITION $MNT
sudo cp $KERNEL $MNT/Image
sync
sudo umount $MNT

# ====== Step 6. Verification ======
echo "[6] Verifying SD card contents"
sudo hexdump -C $DISK | head -n 20
lsblk -f $DISK

echo "🎉 SD card preparation complete, ready to boot FPGA!"
