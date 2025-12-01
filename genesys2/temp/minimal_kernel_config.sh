#!/bin/bash
# Build a minimal Linux kernel for fast boot on Chipyard FPGA
# This creates a ~3-5MB kernel instead of 19MB for faster SPI loading

set -e

LINUX_DIR="/home/ishara/Research/repos/vivado-risc-v/linux-stable"
MINIMAL_CONFIG="/home/ishara/Research/repos/opensbi/chipyard_minimal_defconfig"

echo "=== Building Minimal Linux Kernel for Chipyard ==="
echo "Kernel source: $LINUX_DIR"

cd "$LINUX_DIR"

# Start with tinyconfig (absolute minimum)
echo "[1/5] Creating minimal configuration..."
make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- tinyconfig

# Enable essential features for booting
echo "[2/5] Enabling essential boot features..."
./scripts/config --enable 64BIT
./scripts/config --enable RISCV
./scripts/config --enable RISCV_ISA_C
./scripts/config --enable RISCV_ISA_A
./scripts/config --enable SMP
./scripts/config --enable MMU

# File systems
./scripts/config --enable EXT4_FS
./scripts/config --enable EXT4_USE_FOR_EXT2
./scripts/config --disable EXT4_FS_POSIX_ACL
./scripts/config --disable EXT4_FS_SECURITY

# Essential drivers
./scripts/config --enable SERIAL_SIFIVE
./scripts/config --enable SERIAL_SIFIVE_CONSOLE
./scripts/config --enable SERIAL_EARLYCON_RISCV_SBI
./scripts/config --enable HVC_RISCV_SBI

# SPI and MMC for SD card
./scripts/config --enable SPI
./scripts/config --enable SPI_SIFIVE
./scripts/config --enable MMC
./scripts/config --enable MMC_SPI
./scripts/config --enable MMC_BLOCK

# Block devices
./scripts/config --enable BLK_DEV
./scripts/config --enable BLOCK

# Disable debugging to reduce size
./scripts/config --disable DEBUG_KERNEL
./scripts/config --disable DEBUG_INFO
./scripts/config --disable DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT
./scripts/config --disable KALLSYMS
./scripts/config --disable PRINTK
./scripts/config --enable PRINTK  # Re-enable for boot messages
./scripts/config --disable SYMBOLIC_ERRNAME
./scripts/config --disable BUG
./scripts/config --enable BUG  # Need this for stability

# Disable unnecessary features
./scripts/config --disable MODULES
./scripts/config --disable VIRTUALIZATION
./scripts/config --disable SOUND
./scripts/config --disable WIRELESS
./scripts/config --disable WLAN
./scripts/config --disable ETHERNET
./scripts/config --disable USB_SUPPORT
./scripts/config --disable CRYPTO_MANAGER
./scripts/config --disable SECURITY
./scripts/config --disable AUDIT
./scripts/config --disable NETWORK_FILESYSTEMS

# Essential networking (needed for some init systems)
./scripts/config --enable NET
./scripts/config --enable UNIX
./scripts/config --enable INET

# Device support
./scripts/config --enable DEVTMPFS
./scripts/config --enable DEVTMPFS_MOUNT

# /proc and /sys
./scripts/config --enable PROC_FS
./scripts/config --enable SYSFS

# TTY
./scripts/config --enable TTY
./scripts/config --enable UNIX98_PTYS

# Essential for running init
./scripts/config --enable BINFMT_ELF
./scripts/config --enable BINFMT_SCRIPT

# RTC and timers
./scripts/config --enable RISCV_TIMER

# Interrupt controller
./scripts/config --enable RISCV_INTC
./scripts/config --disable RISCV_APLIC
./scripts/config --disable RISCV_IMSIC

echo "[3/5] Running olddefconfig to resolve dependencies..."
make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- olddefconfig

echo "[4/5] Building minimal kernel (this may take 5-10 minutes)..."
make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- -j$(nproc)

KERNEL_SIZE=$(du -h arch/riscv/boot/Image | cut -f1)
echo ""
echo "[5/5] Build complete!"
echo "Kernel image: $LINUX_DIR/arch/riscv/boot/Image"
echo "Size: $KERNEL_SIZE (vs 19M original)"
echo ""
echo "Expected SPI load time reduction:"
echo "  Original (19MB): ~257 seconds"
echo "  Minimal (est 4MB): ~54 seconds"
echo "  Savings: ~3.5 minutes!"
echo ""
echo "To use this kernel, run make_sdcard.sh"
