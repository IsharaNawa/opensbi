#!/bin/bash
# Test script to verify OpenSBI + U-Boot firmware works
# This creates a minimal SD card with only OpenSBI+U-Boot, no Linux kernel

set -e

# Configuration
UBOOT_DIR=~/Research/repos/u-boot
OPENSBI_DIR=~/Research/repos/opensbi
SD_DEVICE=/dev/sda

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== OpenSBI + U-Boot Test Script ===${NC}"
echo ""

# Step 1: Build OpenSBI with U-Boot payload
echo -e "${YELLOW}Step 1: Building OpenSBI with U-Boot payload...${NC}"
cd $OPENSBI_DIR

make PLATFORM=generic \
     FW_DEBUG=1 \
     CROSS_COMPILE=riscv64-linux-gnu- \
     FW_PAYLOAD_PATH=$UBOOT_DIR/u-boot.bin \
     FW_FDT_PATH=$UBOOT_DIR/arch/riscv/dts/chipyard.fpga.genesys2.GENESYS2FPGATestHarness.RocketGENESYS2Config.dtb \
     -j16

FW_PAYLOAD=$OPENSBI_DIR/build/platform/generic/firmware/fw_payload.bin

if [ ! -f "$FW_PAYLOAD" ]; then
    echo -e "${RED}Error: fw_payload.bin not found!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Firmware built successfully${NC}"
ls -lh $FW_PAYLOAD

# Step 2: Check if SD card is mounted
echo -e "\n${YELLOW}Step 2: Checking SD card...${NC}"
if mount | grep -q $SD_DEVICE; then
    echo -e "${YELLOW}Unmounting SD card partitions...${NC}"
    sudo umount ${SD_DEVICE}* 2>/dev/null || true
fi

# Step 3: Write firmware to SD card
echo -e "\n${YELLOW}Step 3: Writing firmware to SD card at sector 34...${NC}"
echo -e "${RED}WARNING: This will write to $SD_DEVICE${NC}"
read -p "Continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

# Write firmware at sector 34 (offset 17KB)
sudo dd if=$FW_PAYLOAD of=$SD_DEVICE bs=512 seek=34 conv=fsync status=progress

echo -e "\n${GREEN}=== Done! ===${NC}"
echo ""
echo "Firmware written to $SD_DEVICE at sector 34"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Remove SD card safely: sudo eject $SD_DEVICE"
echo "2. Insert SD card into Genesys2 FPGA board"
echo "3. Connect serial console (115200 baud, 8N1)"
echo "4. Power on the board"
echo "5. You should see:"
echo "   - OpenSBI boot messages"
echo "   - U-Boot prompt"
echo ""
echo -e "${YELLOW}At U-Boot prompt, try these commands:${NC}"
echo "   bdinfo       - Show board info"
echo "   printenv     - Show environment variables"
echo "   help         - Show available commands"
