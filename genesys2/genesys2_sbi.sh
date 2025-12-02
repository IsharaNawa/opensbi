#!/usr/bin/bash
set -e

# Variables
CONFIG_FILE="genesys2_defconfig"
OPENSBI_DIR=../
UBOOT_DIR=../u-boot
UBOOT_CONFIG_DIR=$UBOOT_DIR/configs

cd $OPENSBI_DIR

# Extract DTS name from U-Boot config file
if [ ! -f "$UBOOT_CONFIG_DIR/$CONFIG_FILE" ]; then
    echo "Error: U-Boot config file $UBOOT_CONFIG_DIR/$CONFIG_FILE not found"
    exit 1
fi

DTS_NAME=$(grep "CONFIG_DEFAULT_DEVICE_TREE=" $UBOOT_CONFIG_DIR/$CONFIG_FILE | cut -d'"' -f2)
if [ -z "$DTS_NAME" ]; then
    echo "Error: Could not extract DTS name from $CONFIG_FILE"
    exit 1
fi

echo "Building OpenSBI for DTS: $DTS_NAME"

# Set paths
UBOOT_BIN="../build/$DTS_NAME/u-boot.bin"
DTB_FILE="$UBOOT_DIR/arch/riscv/dts/$DTS_NAME.dtb"
BUILD_DIR="../build/$DTS_NAME"

# Check if required files exist
if [ ! -f "$UBOOT_BIN" ]; then
    echo "Error: U-Boot binary not found at $UBOOT_BIN"
    echo "Please run u-boot build first"
    exit 1
fi

if [ ! -f "$DTB_FILE" ]; then
    echo "Error: DTB file not found at $DTB_FILE"
    echo "Please ensure U-Boot was built with the correct DTS"
    exit 1
fi

echo "Cleaning previous OpenSBI build..."
if ! make distclean; then
    echo "Error: Failed to clean previous build"
    exit 1
fi

echo "Building OpenSBI with U-Boot payload..."
if ! make PLATFORM=generic FW_DEBUG=1 \
    CROSS_COMPILE=riscv64-linux-gnu- \
    FW_PAYLOAD_PATH=$UBOOT_BIN \
    FW_FDT_PATH=$DTB_FILE \
    -j16; then
    echo "Error: OpenSBI build failed"
    exit 1
fi

echo "OpenSBI build completed successfully"

# Verify the build output
if [ ! -f "build/platform/generic/firmware/fw_payload.bin" ]; then
    echo "Error: fw_payload.bin not found after build"
    exit 1
fi

if [ ! -f "build/platform/generic/firmware/fw_payload.elf" ]; then
    echo "Error: fw_payload.elf not found after build"
    exit 1
fi

# Check if chipyard string is in the binary
echo "Verifying chipyard string in firmware..."
if strings build/platform/generic/firmware/fw_payload.elf | grep -q chipyard; then
    echo "Chipyard string found in firmware ✓"
else
    echo "Warning: Chipyard string not found in firmware"
fi

# Copy firmware to build directory
echo "Copying firmware binaries to $BUILD_DIR..."
if ! mkdir -p $BUILD_DIR; then
    echo "Error: Failed to create build directory $BUILD_DIR"
    exit 1
fi

if ! cp build/platform/generic/firmware/fw_payload.bin $BUILD_DIR/fw_payload.bin; then
    echo "Error: Failed to copy fw_payload.bin"
    exit 1
fi

if ! cp build/platform/generic/firmware/fw_payload.elf $BUILD_DIR/fw_payload.elf; then
    echo "Error: Failed to copy fw_payload.elf"
    exit 1
fi

# Verify files were copied
if [ ! -f "$BUILD_DIR/fw_payload.bin" ] || [ ! -f "$BUILD_DIR/fw_payload.elf" ]; then
    echo "Error: Firmware files not found in $BUILD_DIR after copy"
    exit 1
fi

echo "Firmware binaries copied to $BUILD_DIR"
echo "  - fw_payload.bin"
echo "  - fw_payload.elf"
echo "OpenSBI build process completed successfully"