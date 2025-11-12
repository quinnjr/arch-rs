# ArchLinux ISO with Rust-Based Utilities

This project provides a build system for creating a custom ArchLinux ISO that replaces GNU core utilities with Rust-based alternatives, including [uutils-coreutils](https://github.com/uutils/coreutils) and many other modern Rust rewrites.

## Prerequisites

- ArchLinux system (or compatible Linux distribution)
- Root/sudo access
- `archiso` package installed
- At least 10GB free disk space

## Installation

1. Install required dependencies:
```bash
sudo pacman -S archiso
```

2. Clone this repository:
```bash
git clone <repository-url> arch-rs
cd arch-rs
```

## Development

This repository follows the [Git Flow](https://nvie.com/posts/a-successful-git-branching-model/) branching model. See [.github/BRANCHING.md](.github/BRANCHING.md) for detailed information about the branching strategy.

### Quick Start for Contributors

```bash
# Clone and set up
git clone <repository-url> arch-rs
cd arch-rs

# Create a feature branch
git checkout develop
git pull origin develop
git checkout -b feature/my-feature

# Make changes, commit, and push
git add .
git commit -m "Add feature: description"
git push origin feature/my-feature

# Create a pull request to develop
```

## Building the ISO

### Local Build

Simply run the build script as root:
```bash
sudo ./build.sh
```

To clean previous build artifacts and start fresh:
```bash
sudo ./build.sh --clean
```

### Automated Build (GitHub Actions)

The ISO is automatically built using GitHub Actions:

- **On version tags** (e.g., `v1.0.0`): Creates a GitHub release with the ISO
- **On main/master branch**: Builds ISO and uploads as artifact (for testing)
- **Manual trigger**: Available from the Actions tab

See [.github/workflows/README.md](.github/workflows/README.md) for more details.

To create a release:
```bash
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

The build process will:
1. Use the custom archiso profile in `profile/`
2. Install `uutils-coreutils` instead of GNU `coreutils`
3. Install additional Rust-based utility replacements (ripgrep, fd, bat, eza, procs, bottom, dust, zoxide, starship, tealdeer, sd, tokei, hyperfine)
4. Configure the system to use rust-based utilities by default
5. Generate a bootable ISO in the `out/` directory

## Project Structure

```
arch-rs/
├── profile/                 # ArchISO profile configuration
│   ├── packages.x86_64     # Package list (uutils-coreutils included)
│   ├── pacman.conf         # Pacman configuration
│   ├── airootfs/           # Root filesystem customizations
│   │   ├── etc/            # System configuration files
│   │   └── root/           # Root user scripts
│   └── build.sh            # Profile build script
├── scripts/                # Utility scripts
│   └── build-coreutils.sh  # Optional: Build coreutils from source
├── work/                   # Build working directory (created during build)
├── out/                    # Output directory for ISO files (created during build)
├── build.sh                # Main build script
└── README.md               # This file
```

## Customization

### Adding/Removing Packages

Edit `profile/packages.x86_64` to add or remove packages from the ISO.

### Modifying System Configuration

- System-wide configs: `profile/airootfs/etc/`
- Root user scripts: `profile/airootfs/root/`
- Customization script: `profile/airootfs/root/customize_airootfs.sh`

### Building Coreutils from Source

If you want to build uutils-coreutils from source instead of using the package:

```bash
./scripts/build-coreutils.sh
```

This requires Rust/Cargo to be installed.

## Testing the ISO

1. Write the ISO to a USB drive:
```bash
sudo dd if=out/archlinux-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

2. Boot from the USB drive in a VM or physical machine

3. Verify rust coreutils is active:
```bash
ls --version  # Should show uutils-coreutils version
which ls      # Should point to uutils binary
```

## Installing to Hard Drive

**Important:** When installing ArchLinux to a hard drive from this ISO, you need to follow special steps to ensure rust coreutils is installed instead of GNU coreutils. See [INSTALL.md](INSTALL.md) for detailed installation instructions.

The ISO includes helper scripts:
- `/root/install-helper.sh` - Run before/during installation
- `/root/post-install.sh` - Run after installation to configure rust coreutils

## Rust-Based Utilities Included

The ISO includes the following Rust-based replacements:

- **uutils-coreutils** - Complete coreutils replacement (ls, cat, cp, mv, rm, etc.)
- **ripgrep (rg)** - Fast grep replacement
- **fd** - Fast find replacement
- **bat** - cat with syntax highlighting
- **eza** - Modern ls replacement
- **procs** - Modern ps replacement
- **bottom (btm)** - System monitor (top/htop replacement)
- **dust** - du replacement with tree view
- **zoxide** - Smart cd replacement
- **starship** - Cross-shell prompt
- **tealdeer (tldr)** - Simplified man pages
- **sd** - Intuitive sed replacement
- **tokei** - Code statistics
- **hyperfine** - Benchmarking tool

See [RUST_UTILITIES.md](RUST_UTILITIES.md) for detailed information about each utility.

## Notes

- The ISO uses Rust-based packages from the Arch repositories
- **GNU counterparts are excluded** - `coreutils`, `grep`, `findutils`, `sed`, and `procps-ng` are excluded from installation
- **Rust utilities are automatically aliased** - standard commands like `grep`, `find`, `cat`, `ls`, `ps`, `top`, `du`, etc. now use Rust versions by default
- Wrapper scripts in `/usr/local/bin` ensure scripts (not just interactive shells) use Rust utilities
- Aliases are active by default in `/etc/profile.d/rust-utils.sh`
- Pacman hooks prevent accidental installation of GNU utilities
- Some scripts may need adjustments if they rely on GNU-specific features or syntax differences
- All standard coreutils commands (ls, cat, cp, mv, etc.) work with uutils-coreutils
- **For installed systems:** Follow the installation guide to ensure rust-based utilities are used on the installed system

## Troubleshooting

### Build fails with "archiso not found"
Install archiso: `sudo pacman -S archiso`

### ISO doesn't boot
- Check that the ISO was written correctly to the USB drive
- Verify your system supports UEFI/BIOS boot mode as configured
- Check the build logs in the `work/` directory

### Coreutils commands not working
- Verify uutils-coreutils is installed: `pacman -Q uutils-coreutils`
- Check binary locations: `which ls` and `ls --version`
- Review the customization scripts in `profile/airootfs/root/`

## License

This build system and configuration files are licensed under the **MIT License**.

See [LICENSE](LICENSE) file for the full license text.

### Third-Party Licenses

The generated ISO includes software packages with their own respective licenses:

- **ArchLinux packages**: Various licenses (GPL, MIT, BSD, etc.) as per ArchLinux distribution
- **uutils-coreutils**: MIT License - https://github.com/uutils/coreutils
- **Rust utilities**:
  - ripgrep: MIT or Unlicense
  - fd: MIT or Apache-2.0
  - bat: MIT or Apache-2.0
  - eza: MIT
  - procs: MIT
  - bottom: MIT
  - dust: Apache-2.0
  - zoxide: MIT
  - starship: ISC
  - tealdeer: MIT or Apache-2.0
  - sd: MIT
  - tokei: MIT or Apache-2.0
  - hyperfine: MIT or Apache-2.0

Users are responsible for complying with all applicable licenses when using the generated ISO or any included software packages. Please refer to the individual package license files for complete license information.

