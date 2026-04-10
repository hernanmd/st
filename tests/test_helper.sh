#!/bin/bash

# Test helper functions for smalltalk tests
# These functions are sourced by bats test files

# Set up test environment
setup_env_vars() {
    if [[ -z "$TMPDIR" ]]; then
        export SMALLTALK_TMPDIR='/tmp'
    else
        export SMALLTALK_TMPDIR="${TMPDIR%/}"
    fi
}

# Get the project root directory
get_project_root() {
    local test_file="$1"
    echo "${test_file%/*}/../.."
}

# Create a temporary directory for tests
make_smalltalk_test_tmpdir() {
    export SMALLTALK_TEST_SUITE_TMPDIR="$SMALLTALK_TMPDIR/smalltalk-test-tmp-$$"
    mkdir -p "$SMALLTALK_TEST_SUITE_TMPDIR"
}

# Clean up test directory
cleanup_test_tmpdir() {
    if [[ -n "$SMALLTALK_TEST_SUITE_TMPDIR" ]]; then
        rm -rf "$SMALLTALK_TEST_SUITE_TMPDIR" 2>/dev/null || true
    fi
}

# Filter ANSI escape sequences from output
filter_ansi_sequences() {
    local cmd="$1"
    shift
    "$@" | sed $'s,\x1b\\[[0-9;]*[a-zA-Z],,g'
}

# Mock tput if not available
if ! command -v tput >/dev/null; then
    tput() {
        printf '1000\n'
    }
fi

# Set up mock cache directory for testing
setup_mock_cache() {
    export SMALLTALK_MOCK_CACHE_DIR="${SMALLTALK_TEST_SUITE_TMPDIR}/mock-cache"
    mkdir -p "$SMALLTALK_MOCK_CACHE_DIR"
}

# Create mock package JSON for testing
create_mock_packages_json() {
    local cache_dir="$1"
    local impl="$2"
    mkdir -p "$cache_dir/$impl"
    cat > "$cache_dir/$impl/packages.json" << 'PKGEOF'
{
  "total_count": 2,
  "items": [
    {
      "full_name": "owner1/package1",
      "description": "Test package 1"
    },
    {
      "full_name": "owner2/package2",
      "description": "Test package 2"
    }
  ]
}
PKGEOF
}

# Get smalltalk command path
get_smalltalk_cmd() {
    local project_root="$1"
    echo "$project_root/bin/smalltalk"
}

# Assert that output contains a string
assert_output_contains() {
    local expected="$1"
    local output="$2"
    if [[ ! "$output" =~ $expected ]]; then
        return 1
    fi
}

# Assert that command exits with expected code
assert_exit_code() {
    local expected="$1"
    local actual="$2"
    if [[ "$expected" != "$actual" ]]; then
        return 1
    fi
}
