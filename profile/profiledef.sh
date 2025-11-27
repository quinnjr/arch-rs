#!/usr/bin/env bash
# profiledef.sh - Profile definition for archiso

# Profile name
profile_name="arch-rs"

# Profile description
profile_desc="ArchLinux ISO with Rust-based Core Utilities"

# ISO label (max 32 chars)
iso_label="ARCH_RS_$(date +%Y%m)"

# ISO publisher
iso_publisher="ArchLinux Rust Coreutils Build System"

# ISO application ID
iso_application="ArchLinux Live/Rescue CD"

# Installation media directory
install_dir="arch"

# Boot modes to build (using modern boot mode names)
bootmodes=('bios.syslinux' 'uefi.systemd-boot')

# Architecture
arch="x86_64"

# Pacman configuration file (required by mkarchiso)
pacman_conf="pacman.conf"

# Pacman mirror to use during build
# Note: This is optional - if not set, archiso will use system default
# pacman_mirror="https://mirror.rackspace.com/archlinux/\$repo/os/\$arch"

# Pacman packages to install
pacman_packages=()

# Pacman packages to exclude (GNU versions replaced by Rust alternatives)
# Note: We can't exclude these during initial installation as they're required dependencies
# Instead, we install them and remove them in customize_airootfs.sh
# pacman_packages_exclude=(
#     coreutils      # Replaced by uutils-coreutils
#     grep           # Replaced by ripgrep
#     findutils      # Replaced by fd
#     sed            # Replaced by sd
#     procps-ng      # Contains ps, top, etc. - Replaced by procs and bottom
# )
pacman_packages_exclude=()

# Optional: AI rootfs image type (default: squashfs)
# airootfs_image_type="squashfs"

# Optional: AI rootfs image tool options
# airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')

