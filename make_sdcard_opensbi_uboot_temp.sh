#!/usr/bin/env bash
set -e

# ====== Path Configuration ======
OPENSBI_DIR=~/Research/repos/opensbi
UBOOT_DIR=~/Research/repos/u-boot
LINUX_DIR=~/Research/repos/linux       # Assumes kernel Image is located here
DISK=/dev/sda           # ⚠️ Change this to your SD card device (e.g., /dev/sde)

FW_PAYLOAD=$OPENSBI_DIR/build/platform/generic/firmware/fw_payload.bin
KERNEL=$LINUX_DIR/arch/riscv/boot/Image
DTB_SRC=$UBOOT_DIR/arch/riscv/dts/chipyard.fpga.genesys2.GENESYS2FPGATestHarness.RocketGENESYS2Config.dtb
DTB_DST=$OPENSBI_DIR/system.dtb   # Copy to OpenSBI directory first

MNT=/mnt/sdcard

# ====== File Verification ======
if [ ! -f "$FW_PAYLOAD" ]; then
  echo "❌ fw_payload.bin not found, please build OpenSBI first"
  exit 1
fi
# Only testing OpenSBI+U-Boot, skip kernel and DTB checks
#if [ ! -f "$KERNEL" ]; then
#  echo "❌ Linux Image not found ($KERNEL)"
#  exit 1
#fi
#if [ ! -f "$DTB_SRC" ]; then
#  echo "❌ U-Boot generated DTB not found ($DTB_SRC)"
#  exit 1
#fi

# ====== Step 0. Copy DTB to OpenSBI directory ======
# Not needed for OpenSBI+U-Boot only test (DTB is embedded in fw_payload.bin)
#echo "[0] Copying DTB to $DTB_DST"
#cp $DTB_SRC $DTB_DST

# ====== Step 1. Clear old partition table ======
# Not needed - we only write firmware to sector 34
#echo "[1] Clearing old data on $DISK"
#sudo wipefs -a $DISK
#sudo dd if=/dev/zero of=$DISK bs=1M count=2 conv=fsync

# ====== Step 2. Write fw_payload.bin to sector 34 ======
echo "[2] Writing fw_payload.bin to $DISK (sector 34)"
sudo dd if=$FW_PAYLOAD of=$DISK bs=512 seek=34 conv=fsync status=progress

# ====== Step 3. Create FAT32 partition ======
# Not needed for OpenSBI+U-Boot only test
#echo "[3] Creating partition table + FAT32 partition"
#sudo parted -s $DISK mklabel msdos
#sudo parted -s $DISK mkpart primary fat32 1MiB 100%
#
#PARTITION=${DISK}1
#sleep 2
#
## ====== Step 4. Format as FAT32 ======
#echo "[4] Formatting $PARTITION as FAT32"
#sudo mkfs.vfat -F 32 $PARTITION
#
## ====== Step 5. Copy Kernel and DTB ======
#echo "[5] Copying kernel Image and system.dtb"
#echo "[5] Copying U-Boot DTB to OpenSBI ($DTB_DST)"
#cp $DTB_SRC $DTB_DST
#sudo mkdir -p $MNT
#sudo mount $PARTITION $MNT
#sudo cp $KERNEL $MNT/Image
#sync
#sudo umount $MNT

# ====== Step 3. Verification ======
echo "[3] Verifying SD card contents"
echo "    First 32 bytes of sector 34:"
sudo dd if=$DISK bs=512 skip=34 count=1 2>/dev/null | hexdump -C | head -n 2

echo ""
echo "🎉 SD card ready for OpenSBI + U-Boot testing!"
echo ""
echo "Next steps:"
echo "  1. Safely eject: sudo eject $DISK"
echo "  2. Insert into Genesys2 FPGA"
echo "  3. Connect serial (115200 8N1)"
echo "  4. Power on and test U-Boot"
