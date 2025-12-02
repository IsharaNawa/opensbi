# Rocket90MHZ Linux Kernel Configuration

## Overview

This directory contains the tested and working Linux kernel configuration for the Rocket90MHZ FPGA setup running on Genesys2 board.

---

## Configuration File

**File**: `rocket90mhz_linux.config`

**Size**: 103 KB

**Base**: Linux 6.15.9 RISC-V 64-bit kernel configuration

**Last Updated**: December 1, 2025

---

## Key Features Enabled

This configuration is specifically tailored for Chipyard/Rocket FPGA designs with the following critical drivers:

### 1. SiFive UART (Serial Console)
```
CONFIG_SERIAL_SIFIVE=y
CONFIG_SERIAL_SIFIVE_CONSOLE=y
```
- Required for serial console output on ttySIF0
- Address: 0x64000000 (from DTB)

### 2. SiFive SPI (SD Card Interface)
```
CONFIG_SPI_SIFIVE=y
CONFIG_SPI_DEBUG=y
```
- SPI controller for SD card communication
- Address: 0x64001000 (from DTB)

### 3. MMC over SPI (SD Card Storage)
```
CONFIG_MMC_SPI=y
CONFIG_MMC_DEBUG=y
```
- SD card block device via SPI
- Creates `/dev/mmcblk0` device

### 4. Additional Debug Support
```
CONFIG_SPI_DEBUG=y
CONFIG_MMC_DEBUG=y
```
- Helps troubleshoot SD card detection and initialization issues

---

## How to Use This Configuration

### Method 1: Direct Copy (Recommended)

```bash
cd /home/ishara/Research/repos/vivado-risc-v/linux-stable

# Backup current config (optional)
cp .config .config.backup

# Use Rocket90MHZ configuration
cp /home/ishara/Research/repos/opensbi/rocket90mhz_linux.config .config

# Apply and build
make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- olddefconfig
make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- -j$(nproc)
```

### Method 2: Start from Defconfig and Apply Changes

```bash
cd /home/ishara/Research/repos/vivado-risc-v/linux-stable

# Start with default RISC-V config
make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- defconfig

# Enable critical drivers
./scripts/config --enable CONFIG_SERIAL_SIFIVE
./scripts/config --enable CONFIG_SERIAL_SIFIVE_CONSOLE
./scripts/config --enable CONFIG_SPI_SIFIVE
./scripts/config --enable CONFIG_SPI_DEBUG
./scripts/config --enable CONFIG_MMC_SPI
./scripts/config --enable CONFIG_MMC_DEBUG

# Apply changes and build
make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- olddefconfig
make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- -j$(nproc)
```

### Method 3: Use in Automated Build Script

```bash
#!/bin/bash
set -e

KERNEL_DIR=/home/ishara/Research/repos/vivado-risc-v/linux-stable
CONFIG_FILE=/home/ishara/Research/repos/opensbi/rocket90mhz_linux.config

cd $KERNEL_DIR

# Use pre-configured kernel config
cp $CONFIG_FILE .config

# Build kernel
make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- olddefconfig
make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- -j$(nproc)

echo "Kernel built successfully: arch/riscv/boot/Image"
```

---

## Comparison with vivado-risc-v Config

### vivado-risc-v (`patches/linux.config`)
- Designed for Vivado custom IP cores
- Uses AXI UART (`CONFIG_SERIAL_AXI_UART=y`)
- Uses custom AXI SD controller
- **Does NOT include** SiFive drivers

### Rocket90MHZ (`rocket90mhz_linux.config`)
- Designed for Chipyard/Rocket SoC
- Uses SiFive UART (`CONFIG_SERIAL_SIFIVE=y`)
- Uses SiFive SPI + MMC-over-SPI
- Based on standard defconfig with minimal additions

---

## Hardware Requirements

This configuration expects the following hardware setup:

### Memory Map (from DTB)
- **DRAM**: 1 GB at 0x80000000
- **Serial**: SiFive UART at 0x64000000
- **SPI**: SiFive SPI controller at 0x64001000
- **PLIC**: Interrupt controller at 0xc000000

### Peripherals
- **Console**: ttySIF0 (SiFive UART)
- **Storage**: SD card via SPI (`/dev/mmcblk0`)
- **Timer**: RISC-V ACLINT @ 90 kHz (from DTB)

### Expected Device Tree Properties
```dts
serial@64000000 {
    compatible = "sifive,uart0";
};

spi@64001000 {
    compatible = "sifive,spi0";
    mmc@0 {
        compatible = "mmc-spi-slot";
    };
};
```

---

## Verification

After building the kernel with this configuration, verify the drivers are compiled:

```bash
cd /home/ishara/Research/repos/vivado-risc-v/linux-stable

# Check for SiFive UART driver
grep CONFIG_SERIAL_SIFIVE .config
# Expected: CONFIG_SERIAL_SIFIVE=y

# Check for SPI driver
grep CONFIG_SPI_SIFIVE .config
# Expected: CONFIG_SPI_SIFIVE=y

# Check for MMC over SPI
grep CONFIG_MMC_SPI .config
# Expected: CONFIG_MMC_SPI=y

# Verify kernel image was built
ls -lh arch/riscv/boot/Image
# Expected: ~19 MB kernel image
```

---

## Boot Test Results

This configuration has been successfully tested on:

- **Hardware**: Genesys2 FPGA board
- **FPGA Config**: Rocket90MHZ (90 MHz CPU, 90 kHz timer)
- **Bootloader**: OpenSBI v1.7 + U-Boot 2025.10-rc2
- **Storage**: 64 GB SD card via SPI
- **Root FS**: Debian GNU/Linux 13 (trixie)

### Boot Log Verification
```
[    1.535577] 64000000.serial: ttySIF0 at MMIO 0x64000000 (irq = 12) is a SiFive UART v0
[    1.655499] sifive_spi 64001000.spi: mapped; irq=13, cs=1
[    1.751633] mmc_spi spi0.0: SD/MMC host mmc0, no WP, no poweroff, cd polling
[    2.069088] mmc0: new SDXC card on SPI
[    2.082977] mmcblk0: mmc0:0000 SR64G 59.5 GiB
[    2.118922]  mmcblk0: p1 p2
[    5.032733] EXT4-fs (mmcblk0p2): mounted filesystem
```

All drivers loaded successfully and system boots to login prompt.

---

## Troubleshooting

### Issue: Kernel hangs at "Starting kernel..."
**Cause**: `CONFIG_SERIAL_SIFIVE` is not enabled  
**Solution**: Use this config file or enable the driver manually

### Issue: SD card not detected
**Cause**: Missing `CONFIG_SPI_SIFIVE` or `CONFIG_MMC_SPI`  
**Solution**: Use this config file which has both enabled

### Issue: Build fails with missing symbols
**Cause**: Kernel version mismatch or missing dependencies  
**Solution**: Ensure you're using Linux 6.15.9 and run `make olddefconfig`

---

## Updating the Configuration

If you need to modify this configuration:

```bash
cd /home/ishara/Research/repos/vivado-risc-v/linux-stable

# Load current config
cp /home/ishara/Research/repos/opensbi/rocket90mhz_linux.config .config

# Make changes via menuconfig
make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- menuconfig

# Save updated config
cp .config /home/ishara/Research/repos/opensbi/rocket90mhz_linux.config

# Build to verify
make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- -j$(nproc)
```

---

## Integration with make_sdcard.sh

The `make_sdcard.sh` script expects the kernel to be built at:
```
/home/ishara/Research/repos/vivado-risc-v/linux-stable/arch/riscv/boot/Image
```

After using this configuration and building the kernel, the script will automatically use the correct kernel image.

---

## Related Files

- **Kernel Config**: `rocket90mhz_linux.config` (this config)
- **U-Boot DTS**: `/home/ishara/Research/repos/u-boot/arch/riscv/dts/Rocket90MHZ.dts`
- **U-Boot Config**: `/home/ishara/Research/repos/u-boot/configs/Rocket90MHZ_defconfig`
- **Build Guide**: `SD_CARD_BUILD_STEPS.md`
- **SD Card Script**: `make_sdcard.sh`

---

## Version History

### v1.0 - December 1, 2025
- Initial release
- Based on Linux 6.15.9 defconfig
- SiFive UART, SPI, and MMC-SPI drivers enabled
- Debug support enabled for SPI and MMC
- Successfully tested on Rocket90MHZ hardware

---

## Notes

- This configuration is **minimal** - only essential drivers for Rocket90MHZ are enabled
- Based on standard RISC-V defconfig for maximum compatibility
- Debug options enabled to aid troubleshooting during early development
- Can be used as a starting point for additional customization

For questions or issues, refer to `SD_CARD_BUILD_STEPS.md` for complete build instructions.
