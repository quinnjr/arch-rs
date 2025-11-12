# Installation Guide: ArchLinux with Rust-Based Utilities

This guide explains how to install ArchLinux to a hard drive using this ISO, ensuring that rust-based utilities (uutils-coreutils and other Rust replacements) are installed instead of their GNU counterparts.

## Important Notes

**The ISO itself uses rust-based utilities**, but when installing to a hard drive, you need to follow these steps to ensure the installed system also uses rust-based utilities instead of GNU utilities.

## Installation Methods

### Method 1: Manual Installation (Recommended)

When installing ArchLinux manually using `pacstrap`:

1. **Boot from the ISO** and follow standard ArchLinux installation steps until you reach the package installation step.

2. **Install base system excluding GNU utilities:**
   ```bash
   pacstrap /mnt base --ignore coreutils,grep,findutils,sed,procps-ng
   ```

3. **Install rust-based utilities:**
   ```bash
   pacstrap /mnt uutils-coreutils
   pacstrap /mnt ripgrep fd bat eza procs bottom dust zoxide starship tealdeer sd tokei hyperfine
   ```

4. **Configure the installed system:**
   ```bash
   # Copy the installation helper script
   cp /root/install-helper.sh /mnt/root/
   chmod +x /mnt/root/install-helper.sh

   # Run the helper script
   arch-chroot /mnt /root/install-helper.sh /mnt
   ```

5. **Continue with normal installation steps** (fstab, chroot, etc.)

6. **After chrooting into the installed system, run the post-install script:**
   ```bash
   arch-chroot /mnt
   /root/post-install.sh
   ```

### Method 2: Using archinstall (Semi-Automated)

If using `archinstall`:

1. **Boot from the ISO** and run `archinstall`

2. **After installation completes**, before rebooting, run:
   ```bash
   arch-chroot /mnt /root/post-install.sh
   ```

3. This will replace GNU coreutils with rust coreutils and install additional Rust-based utilities on the installed system.

### Method 3: Automated Helper Script

The ISO includes an installation helper script that can be used:

1. **After mounting your installation target:**
   ```bash
   /root/install-helper.sh /mnt
   ```

2. **Install base system:**
   ```bash
   pacstrap /mnt base --ignore coreutils,grep,findutils,sed,procps-ng
   pacstrap /mnt uutils-coreutils
   pacstrap /mnt ripgrep fd bat eza procs bottom dust zoxide starship tealdeer sd tokei hyperfine
   ```

3. **After chrooting, run:**
   ```bash
   arch-chroot /mnt /root/post-install.sh
   ```

## What These Scripts Do

### `install-helper.sh`
- Configures pacman hooks to prevent GNU coreutils installation
- Sets up `pacman.conf` to ignore coreutils package
- Can replace coreutils if already installed

### `post-install.sh`
- Removes GNU coreutils if present
- Installs uutils-coreutils and other Rust-based utilities
- Configures pacman to ignore coreutils in future installations
- Sets up symlinks for coreutils commands
- **Creates wrapper scripts in `/usr/local/bin`** for system-wide Rust utility access
- **Configures active aliases** in `/etc/profile.d/rust-utils.sh` (enabled by default)
- Updates shell profiles to source the aliases automatically

## Verification

After installation, verify that rust-based utilities are active:

```bash
# Check coreutils
ls --version  # Should show uutils-coreutils version
which ls      # Should point to uutils binary
pacman -Q coreutils  # Should show "error: package 'coreutils' was not found"
pacman -Q uutils-coreutils  # Should show the installed package

# Check other Rust utilities
rg --version    # ripgrep
fd --version    # fd
bat --version   # bat
eza --version   # eza
procs --version # procs
btm --version   # bottom
dust --version  # dust
zoxide --version # zoxide
starship --version # starship
tldr --version  # tealdeer
sd --version    # sd
tokei --version # tokei
hyperfine --version # hyperfine
```

## Pacman Configuration

The installed system will have:
- `IgnorePkg = coreutils grep findutils sed procps-ng` in `/etc/pacman.conf`
- Pacman hooks in `/etc/pacman.d/hooks/` that prevent GNU utilities installation:
  - `coreutils-replace.hook`
  - `grep-replace.hook`
  - `findutils-replace.hook`
  - `sed-replace.hook`
  - `procps-ng-replace.hook`

This ensures that even if you accidentally try to install `coreutils` later, it will be automatically replaced with `uutils-coreutils`.

## Troubleshooting

### GNU utilities were installed by mistake

If GNU utilities were installed during installation:

```bash
pacman -Rns coreutils grep findutils sed procps-ng
pacman -S uutils-coreutils ripgrep fd sd procs bottom
/root/post-install.sh
```

### Commands not working after installation

Ensure uutils-coreutils is installed and symlinks are created:

```bash
pacman -S uutils-coreutils
# The post-install.sh script will create necessary symlinks
```

### Package conflicts

If you encounter package conflicts, you may need to:

```bash
pacman -Rdd coreutils  # Force remove (breaks dependencies)
pacman -S uutils-coreutils
```

## Notes

- The `base` package group includes `coreutils`, `grep`, `findutils`, `sed`, and `procps-ng` as dependencies
- Using `--ignore coreutils,grep,findutils,sed,procps-ng` with pacstrap prevents them from being installed
- Some packages may list these as dependencies, but the Rust alternatives provide the same functionality
- The pacman hooks will automatically prevent GNU utilities installation in the future
- The `IgnorePkg` setting in `/etc/pacman.conf` ensures pacman won't install or upgrade these packages

