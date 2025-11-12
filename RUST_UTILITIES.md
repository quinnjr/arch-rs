# Rust-Based Linux Utility Replacements

This document lists the Rust-based replacements for core Linux utilities that can be used in this ArchLinux ISO.

## Core Utilities (Already Included)

- **uutils-coreutils** - Complete replacement for GNU coreutils (ls, cat, cp, mv, rm, etc.)

## Additional Rust-Based Replacements

### Search & Text Processing

- **ripgrep (rg)** - Fast grep replacement
  - Package: `ripgrep` (in [community])
  - Replaces: `grep`
  - Features: Much faster than grep, respects .gitignore by default

- **fd** - Fast find replacement
  - Package: `fd` (in [community])
  - Replaces: `find`
  - Features: Simpler syntax, faster, colorized output

- **bat** - cat with syntax highlighting
  - Package: `bat` (in [community])
  - Replaces: `cat`
  - Features: Syntax highlighting, Git integration, paging

- **sd** - Intuitive find & replace
  - Package: `sd` (in [community])
  - Replaces: `sed` (for simple replacements)
  - Features: Simpler syntax than sed

### File Listing & Navigation

- **eza** - Modern ls replacement
  - Package: `eza` (in [community], successor to exa)
  - Replaces: `ls`
  - Features: Git integration, tree view, better colors

- **zoxide** - Smart cd replacement
  - Package: `zoxide` (in [community])
  - Replaces: `cd` (with smart directory jumping)
  - Features: Learns your habits, faster navigation

### System Monitoring

- **procs** - Modern ps replacement
  - Package: `procs` (in [community])
  - Replaces: `ps`
  - Features: Colorized output, better formatting

- **bottom (btop)** - System monitor
  - Package: `bottom` (in [community])
  - Replaces: `top`, `htop`
  - Features: Modern UI, better visualization

- **dust** - du replacement
  - Package: `dust` (in [community])
  - Replaces: `du`
  - Features: More intuitive output, tree view

### Development Tools

- **tokei** - Code statistics
  - Package: `tokei` (in [community])
  - Replaces: `wc` (for code analysis)
  - Features: Counts lines of code by language

- **hyperfine** - Benchmarking tool
  - Package: `hyperfine` (in [community])
  - Replaces: `time` (for benchmarking)
  - Features: Statistical analysis, warmup runs

### Documentation

- **tealdeer (tldr)** - Simplified man pages
  - Package: `tealdeer` (in [community])
  - Replaces: `man` (for quick reference)
  - Features: Practical examples, community-driven

### Shell Enhancement

- **starship** - Cross-shell prompt
  - Package: `starship` (in [community])
  - Replaces: Custom prompt configurations
  - Features: Fast, customizable, shows Git status

## Package Availability

All listed packages are available in the official ArchLinux [community] repository, making them easy to install and maintain.

## Automatic Aliasing

**All Rust utilities are automatically aliased to their GNU counterparts by default:**
- `grep` → `rg` (ripgrep)
- `find` → `fd`
- `cat` → `bat` (with `--paging=never` for scripts)
- `sed` → `sd`
- `ls` → `eza` (overrides uutils ls)
- `ps` → `procs`
- `top` / `htop` → `btm` (bottom)
- `du` → `dust`
- `cd` → `zoxide` (smart directory jumping)
- Shell prompt → `starship` (if enabled)

**Implementation:**
- **Interactive shells:** Aliases in `/etc/profile.d/rust-utils.sh` (active by default)
- **Scripts:** Wrapper scripts in `/usr/local/bin` ensure scripts also use Rust utilities
- `/usr/local/bin` is added to PATH early, so wrappers take precedence

## Compatibility Notes

- **uutils-coreutils** provides most coreutils commands, but **eza** is used for `ls` and **bat** for `cat` due to additional features
- **ripgrep** and **fd** are mostly drop-in replacements but have slightly different syntax in some cases
- **procs** and **bottom** offer enhanced features but may require script adjustments
- **bat** uses `--paging=never` by default for scripts; use `batp` alias for interactive paging
- Most utilities maintain compatibility with their GNU counterparts for basic usage

## Installation Priority

For a minimal Rust-based system:
1. **uutils-coreutils** (essential - already included)
2. **ripgrep** (highly recommended - much faster than grep)
3. **fd** (highly recommended - simpler than find)
4. **bat** (recommended - better than cat for code)
5. **eza** (optional - if you want enhanced ls features)

For a full Rust-based experience, include all utilities listed above.

