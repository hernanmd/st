#!/usr/bin/env bats

# ============================================================================
# test-common-functions.bats - Tests for smalltalk-common.sh
# ============================================================================

# Get project root
PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
MANIFEST_FILE="${HOME}/.smalltalk-manifest.json"

# Setup
setup() {
    # Save and clear manifest for clean test state
    if [[ -f "$MANIFEST_FILE" ]]; then
        cp "$MANIFEST_FILE" "${BATS_TMPDIR}/manifest.backup.$$"
    fi
    echo '{}' > "$MANIFEST_FILE"
}

teardown() {
    # Restore manifest
    if [[ -f "${BATS_TMPDIR}/manifest.backup.$$" ]]; then
        mv "${BATS_TMPDIR}/manifest.backup.$$" "$MANIFEST_FILE"
    fi
}

# ============================================================================
# OS Detection Tests
# ============================================================================

@test "get_os returns valid OS type" {
    local os
    os=$(bash -c "source '$PROJECT_ROOT/libexec/smalltalk-common.sh' && get_os")
    [[ "$os" == "linux" || "$os" == "macos" || "$os" == "windows" ]]
}

@test "get_arch returns valid architecture" {
    local arch
    arch=$(bash -c "source '$PROJECT_ROOT/libexec/smalltalk-common.sh' && get_arch")
    [[ "$arch" == "x86_64" || "$arch" == "arm64" || "$arch" == "x86" || "$arch" == "arm" ]]
}

# ============================================================================
# Logging Function Tests
# ============================================================================

@test "log_info outputs to stdout with [INFO] prefix" {
    run bash -c "source '$PROJECT_ROOT/libexec/smalltalk-common.sh' && log_info 'test message'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[INFO]"* ]]
    [[ "$output" == *"test message"* ]]
}

@test "log_error outputs to stderr with [ERROR] prefix" {
    run bash -c "source '$PROJECT_ROOT/libexec/smalltalk-common.sh' && log_error 'error message' 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[ERROR]"* ]]
    [[ "$output" == *"error message"* ]]
}

@test "log_success outputs with [SUCCESS] prefix" {
    run bash -c "source '$PROJECT_ROOT/libexec/smalltalk-common.sh' && log_success 'success message'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[SUCCESS]"* ]]
}

# ============================================================================
# Cache Directory Tests
# ============================================================================

@test "CACHE_DIR is set to default location" {
    run bash -c "source '$PROJECT_ROOT/libexec/smalltalk-common.sh' && echo \"\$CACHE_DIR\""
    [[ "$output" == *".smalltalk-cache"* ]]
}

@test "clean_impl_cache handles non-existent cache" {
    run bash -c "source '$PROJECT_ROOT/libexec/smalltalk-common.sh' && clean_impl_cache 'nonexistent_impl'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"does not exist"* ]]
}

# ============================================================================
# Die Function Tests
# ============================================================================

@test "die exits with code 1 and outputs to stderr" {
    run bash -c "source '$PROJECT_ROOT/libexec/smalltalk-common.sh' && die 'fatal error' 2>&1" || true
    [ "$status" -eq 1 ]
    [[ "$output" == *"[ERROR]"* ]]
    [[ "$output" == *"fatal error"* ]]
}

# ============================================================================
# Archive Extraction Tests
# ============================================================================

@test "extract_archive fails for unsupported format" {
    touch "${BATS_TMPDIR}/test.7z"
    run bash -c "source '$PROJECT_ROOT/libexec/smalltalk-common.sh' && extract_archive '${BATS_TMPDIR}/test.7z' '${BATS_TMPDIR}' 2>&1" || true
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unsupported archive format"* ]]
}

# ============================================================================
# Confirm Function Tests
# ============================================================================

@test "confirm function is defined" {
    run bash -c "source '$PROJECT_ROOT/libexec/smalltalk-common.sh' && type confirm" || true
    [[ "$output" == *"confirm is a function"* ]]
}

# ============================================================================
# Monticello Package Functions Tests
# ============================================================================

@test "list_monticello_packages handles missing cache" {
    export CACHE_DIR="${BATS_TMPDIR}/nonexistent"
    run bash -c "source '$PROJECT_ROOT/libexec/smalltalk-common.sh' && list_monticello_packages 'pharo' 'pharo' 2>&1" || true
    [ "$status" -eq 1 ]
    [[ "$output" == *"update"* ]]
}

# ============================================================================
# Manifest Tests
# ============================================================================

@test "init_manifest creates manifest file" {
    local test_manifest="${BATS_TMPDIR}/test-manifest-$$.json"
    export MANIFEST_FILE="$test_manifest"
    
    run bash -c "source '$PROJECT_ROOT/libexec/smalltalk-common.sh' && init_manifest && cat \"\$MANIFEST_FILE\""
    [ "$status" -eq 0 ]
    [[ "$output" == "{}" ]]
}

@test "manifest_add adds entry to manifest" {
    local test_manifest="${BATS_TMPDIR}/test-manifest-$$.json"
    export MANIFEST_FILE="$test_manifest"
    
    run bash -c "source '$PROJECT_ROOT/libexec/smalltalk-common.sh' && init_manifest && manifest_add 'testimpl' '/tmp/test' '/tmp/file1' '/tmp/file2' && cat \"\$MANIFEST_FILE\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"testimpl"* ]]
}

@test "manifest_get_dir retrieves install directory" {
    local test_manifest="${BATS_TMPDIR}/test-manifest-$$.json"
    export MANIFEST_FILE="$test_manifest"
    
    run bash -c "source '$PROJECT_ROOT/libexec/smalltalk-common.sh' && init_manifest && manifest_add 'testimpl' '/tmp/test' && manifest_get_dir 'testimpl'"
    [ "$status" -eq 0 ]
    [[ "$output" == "/tmp/test" ]]
}

# ============================================================================
# Detect Existing Smalltalk Tests
# ============================================================================

@test "detect_existing_smalltalk returns empty for non-smalltalk directory" {
    local empty_dir="${BATS_TMPDIR}/empty-dir-$$"
    mkdir -p "$empty_dir"
    
    run bash -c "source '$PROJECT_ROOT/libexec/smalltalk-common.sh' && detect_existing_smalltalk '$empty_dir'"
    [ "$status" -eq 1 ]
}

# ============================================================================
# Ensure Install Dir Tests
# ============================================================================

@test "ensure_install_dir creates directory if not exists" {
    local new_dir="${BATS_TMPDIR}/new-test-dir-$$"
    
    run bash -c "source '$PROJECT_ROOT/libexec/smalltalk-common.sh' && ensure_install_dir '$new_dir'"
    [ "$status" -eq 0 ]
    [[ -d "$new_dir" ]]
}

# ============================================================================
# Clean Artifacts Tests
# ============================================================================

@test "clean_impl_artifacts handles empty manifest" {
    local test_manifest="${BATS_TMPDIR}/test-manifest-$$.json"
    export MANIFEST_FILE="$test_manifest"
    
    run bash -c "source '$PROJECT_ROOT/libexec/smalltalk-common.sh' && init_manifest && clean_impl_artifacts 'nonexistent' 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"clean"* ]]
}
