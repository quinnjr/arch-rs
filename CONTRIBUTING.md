# Contributing to ArchLinux ISO with Rust Utilities

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing to this project.

## Development Workflow

This project follows the [Git Flow](https://nvie.com/posts/a-successful-git-branching-model/) branching model. Please read [.github/BRANCHING.md](.github/BRANCHING.md) for detailed information about the branching strategy.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork**:
   ```bash
   git clone https://github.com/YOUR_USERNAME/arch-rs.git
   cd arch-rs
   ```
3. **Add upstream remote**:
   ```bash
   git remote add upstream https://github.com/ORIGINAL_OWNER/arch-rs.git
   ```

## Making Changes

### For New Features

1. **Update your local develop branch**:
   ```bash
   git checkout develop
   git pull upstream develop
   ```

2. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes** and commit:
   ```bash
   git add .
   git commit -m "Add feature: brief description"
   ```

4. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

5. **Create a Pull Request** from your feature branch to `develop`

### For Bug Fixes

1. **Create a hotfix branch** (if fixing production):
   ```bash
   git checkout main
   git pull upstream main
   git checkout -b hotfix/bug-description
   ```

   Or create a feature branch from develop (if fixing development):
   ```bash
   git checkout develop
   git pull upstream develop
   git checkout -b feature/fix-bug-description
   ```

2. **Make your changes** and commit:
   ```bash
   git add .
   git commit -m "Fix: brief description of the bug fix"
   ```

3. **Push and create a Pull Request**

## Commit Message Guidelines

Follow these guidelines for commit messages:

- Use the present tense ("Add feature" not "Added feature")
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit the first line to 72 characters or less
- Reference issues and pull requests liberally after the first line

### Format

```
Type: Brief description (50 chars max)

More detailed explanation if needed. Wrap it to about 72 characters or so.
In some contexts, the first line is treated as the subject of an email
and the rest of the text as the body. The blank line separating the
summary from the body is critical.

- Bullet points are okay, too
- Typically a hyphen or asterisk is used for the bullet, followed by a
  single space, with blank lines in between

Closes #123
```

### Types

- `Add`: New feature
- `Fix`: Bug fix
- `Update`: Update existing feature
- `Remove`: Remove feature or code
- `Refactor`: Code refactoring
- `Docs`: Documentation changes
- `Test`: Adding or updating tests
- `Build`: Build system or CI changes

## Testing

Before submitting a pull request, ensure:

1. **All tests pass**:
   ```bash
   bash tests/build.test.sh
   ```

2. **Scripts have valid syntax**:
   ```bash
   find . -name "*.sh" -exec bash -n {} \;
   ```

3. **Required files are present** (see tests for list)

## Pull Request Process

1. **Update your branch** with the latest changes:
   ```bash
   git checkout develop
   git pull upstream develop
   git checkout feature/your-feature-name
   git rebase develop
   ```

2. **Ensure all tests pass** (see Testing section)

3. **Create a Pull Request**:
   - Use the PR template
   - Provide a clear description
   - Link related issues
   - Request review from maintainers

4. **Address review feedback**:
   - Make requested changes
   - Push updates to your branch
   - The PR will automatically update

## Code Style

- **Bash scripts**: Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- **Indentation**: Use 2 spaces (not tabs)
- **Line length**: Keep lines under 100 characters when possible
- **Comments**: Add comments for complex logic
- **Error handling**: Use `set -euo pipefail` in scripts

## Project Structure

```
arch-rs/
├── profile/              # ArchISO profile configuration
│   ├── packages.x86_64  # Package list
│   ├── pacman.conf      # Pacman configuration
│   └── airootfs/        # Root filesystem customizations
├── scripts/             # Utility scripts
├── tests/               # Test files
├── .github/             # GitHub workflows and templates
└── build.sh             # Main build script
```

## Questions?

- Open an issue for questions or discussions
- Check existing issues and PRs first
- Be respectful and constructive in all communications

## License

By contributing, you agree that your contributions will be licensed under the MIT License, the same license as the project.

This means:
- Your contributions will be available under the MIT License
- You retain copyright to your contributions
- You grant permission for your contributions to be used, modified, and distributed under the MIT License

