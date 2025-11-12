#!/usr/bin/env bash
# Unit tests for the build system

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

test_pass() {
    echo "✓ PASS: $1"
    ((TESTS_PASSED++)) || true
}

test_fail() {
    echo "✗ FAIL: $1"
    ((TESTS_FAILED++)) || true
}

# Test 1: Check if required files exist
test_required_files() {
    local files=(
        "$PROJECT_DIR/build.sh"
        "$PROJECT_DIR/profile/packages.x86_64"
        "$PROJECT_DIR/profile/pacman.conf"
        "$PROJECT_DIR/profile/profiledef.sh"
        "$PROJECT_DIR/profile/airootfs/root/customize_airootfs.sh"
        "$PROJECT_DIR/profile/airootfs/root/.automated_script.sh"
    )

    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            test_pass "Required file exists: $(basename "$file")"
        else
            test_fail "Required file missing: $file"
        fi
    done
}

# Test 2: Check if scripts are executable
test_script_permissions() {
    local scripts=(
        "$PROJECT_DIR/build.sh"
        "$PROJECT_DIR/profile/airootfs/root/customize_airootfs.sh"
        "$PROJECT_DIR/profile/airootfs/root/.automated_script.sh"
    )

    for script in "${scripts[@]}"; do
        if [ -x "$script" ]; then
            test_pass "Script is executable: $(basename "$script")"
        else
            test_fail "Script is not executable: $script"
        fi
    done
}

# Test 3: Check if packages.x86_64 contains uutils-coreutils
test_package_list() {
    if grep -q "uutils-coreutils" "$PROJECT_DIR/profile/packages.x86_64"; then
        test_pass "uutils-coreutils is in package list"
    else
        test_fail "uutils-coreutils is missing from package list"
    fi

    if grep -q "^coreutils$" "$PROJECT_DIR/profile/packages.x86_64"; then
        test_fail "GNU coreutils should not be in package list"
    else
        test_pass "GNU coreutils is not in package list (correct)"
    fi
}

# Test 4: Check if profiledef.sh excludes coreutils
test_profiledef_excludes() {
    if grep -A 5 "pacman_packages_exclude=(" "$PROJECT_DIR/profile/profiledef.sh" | grep -q "coreutils"; then
        test_pass "profiledef.sh excludes coreutils"
    else
        test_fail "profiledef.sh should explicitly exclude coreutils in pacman_packages_exclude"
    fi
}

# Test 5: Validate bash syntax of scripts
test_bash_syntax() {
    local scripts=(
        "$PROJECT_DIR/build.sh"
        "$PROJECT_DIR/profile/airootfs/root/customize_airootfs.sh"
        "$PROJECT_DIR/profile/airootfs/root/.automated_script.sh"
    )

    for script in "${scripts[@]}"; do
        if bash -n "$script" 2>/dev/null; then
            test_pass "Bash syntax valid: $(basename "$script")"
        else
            test_fail "Bash syntax error in: $script"
        fi
    done
}

# Test 6: Check if customize_airootfs.sh removes GNU utilities
test_customize_removes_coreutils() {
    if grep -q "GNU_PACKAGES" "$PROJECT_DIR/profile/airootfs/root/customize_airootfs.sh" && \
       grep -q "coreutils" "$PROJECT_DIR/profile/airootfs/root/customize_airootfs.sh" && \
       grep -q "pacman -Rns" "$PROJECT_DIR/profile/airootfs/root/customize_airootfs.sh"; then
        test_pass "customize_airootfs.sh removes GNU utilities (including coreutils)"
    else
        test_fail "customize_airootfs.sh should remove GNU utilities"
    fi
}

# Test 7: Check if customize_airootfs.sh installs uutils-coreutils
test_customize_installs_uutils() {
    if grep -q "uutils-coreutils" "$PROJECT_DIR/profile/airootfs/root/customize_airootfs.sh"; then
        test_pass "customize_airootfs.sh installs uutils-coreutils"
    else
        test_fail "customize_airootfs.sh should install uutils-coreutils"
    fi
}

# Run all tests
echo "Running build system tests..."
echo "================================"
echo ""

test_required_files
test_script_permissions
test_package_list
test_profiledef_excludes
test_bash_syntax
test_customize_removes_coreutils
test_customize_installs_uutils

echo ""
echo "================================"
echo "Test Results:"
echo "  Passed: $TESTS_PASSED"
echo "  Failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo "All tests passed! ✓"
    exit 0
else
    echo "Some tests failed. Please review the output above."
    exit 1
fi

