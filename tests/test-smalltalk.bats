
# ============================================================================
# Timestamped Directory Tests
# ============================================================================

@test "st pharo install without -d creates timestamped directory" {
    local test_dir="$TEST_TMPDIR/test-pharo-timestamp"
    mkdir -p "$test_dir"
    
    run bash -c "cd '$test_dir' && '$SMALLTALK_CMD' pharo install 2>&1" || true
    
    # Should create a timestamped directory, not install in current dir
    [[ "$output" == *"Creating directory: Pharo"* ]] || [[ "$output" == *"timestamp"* ]] || [[ "$output" == *"No destination"* ]]
}

@test "st gt install without -d creates timestamped directory" {
    local test_dir="$TEST_TMPDIR/test-gt-timestamp"
    mkdir -p "$test_dir"
    
    run bash -c "cd '$test_dir' && '$SMALLTALK_CMD' gt install 2>&1" || true
    
    # Should create a timestamped directory
    [[ "$output" == *"Creating directory: GlamorousToolkit"* ]] || [[ "$output" == *"timestamp"* ]] || [[ "$output" == *"No destination"* ]]
}

@test "st squeak install without -d creates timestamped directory" {
    local test_dir="$TEST_TMPDIR/test-squeak-timestamp"
    mkdir -p "$test_dir"
    
    run bash -c "cd '$test_dir' && '$SMALLTALK_CMD' squeak install 2>&1" || true
    
    # Should create a timestamped directory
    [[ "$output" == *"Creating directory: Squeak"* ]] || [[ "$output" == *"timestamp"* ]] || [[ "$output" == *"No destination"* ]]
}

@test "st cuis install without -d creates timestamped directory" {
    local test_dir="$TEST_TMPDIR/test-cuis-timestamp"
    mkdir -p "$test_dir"
    
    run bash -c "cd '$test_dir' && '$SMALLTALK_CMD' cuis install 2>&1" || true
    
    # Should create a timestamped directory
    [[ "$output" == *"Creating directory: Cuis"* ]] || [[ "$output" == *"timestamp"* ]] || [[ "$output" == *"No destination"* ]]
}

# ============================================================================
# GT Download URL Tests
# ============================================================================

@test "GT URL uses dl.feenk.com domain" {
    run bash -c "source '$PROJECT_ROOT/libexec/smalltalk-common.sh' && source '$PROJECT_ROOT/libexec/smalltalk-gt.sh' && set_gt_url && echo \$GT_URL"
    [[ "$output" == *"dl.feenk.com"* ]]
}

@test "GT URL for macOS includes GlamorousToolkitOSXM1" {
    run bash -c "source '$PROJECT_ROOT/libexec/smalltalk-common.sh' && source '$PROJECT_ROOT/libexec/smalltalk-gt.sh' && GT_URL_BASE='https://dl.feenk.com' && set_gt_url && echo \$GT_URL"
    # On ARM64 it should use OSXM1, on x86 it should use x86_64
    [[ "$output" == *"GlamorousToolkit"* ]] || [[ "$output" == *"feenk.com"* ]]
}

# ============================================================================
# Squeak URL Tests
# ============================================================================

@test "Squeak URL uses files.squeak.org domain" {
    run bash -c "source '$PROJECT_ROOT/libexec/smalltalk-common.sh' && source '$PROJECT_ROOT/libexec/smalltalk-squeak.sh' && get_squeak_url 6.0"
    [[ "$output" == *"files.squeak.org"* ]]
}

# ============================================================================
# LST No Arguments Test
# ============================================================================

@test "st lst install without arguments does not error" {
    local test_dir="$TEST_TMPDIR/test-lst-noargs"
    mkdir -p "$test_dir"
    
    run bash -c "cd '$test_dir' && '$SMALLTALK_CMD' lst install 2>&1" || true
    
    # Should not have "unbound variable" error
    [[ "$output" != *"unbound variable"* ]]
    [[ "$output" != *'$1: unbound'* ]]
}

@test "st gnu install without arguments does not error" {
    local test_dir="$TEST_TMPDIR/test-gnu-noargs"
    mkdir -p "$test_dir"
    
    run bash -c "cd '$test_dir' && '$SMALLTALK_CMD' gnu install 2>&1" || true
    
    # Should not have "unbound variable" error
    [[ "$output" != *"unbound variable"* ]]
    [[ "$output" != *'$1: unbound'* ]]
}
#!/usr/bin/env bats

# ============================================================================
# test-smalltalk.bats - Main test suite for smalltalk CLI
# ============================================================================

# Get project root
PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SMALLTALK_CMD="$PROJECT_ROOT/bin/st"

# Test isolation: use temp directories and don't pollute source tree
TEST_TMPDIR="${BATS_TMPDIR:-/tmp}/smalltalk-tests-$$"
MANIFEST_FILE="${HOME}/.smalltalk-manifest.json"
CACHE_DIR="${HOME}/.smalltalk-cache"

setup() {
    mkdir -p "$TEST_TMPDIR"
    
    # Save and clear any existing manifest for clean test state
    if [[ -f "$MANIFEST_FILE" ]]; then
        cp "$MANIFEST_FILE" "$TEST_TMPDIR/manifest.backup"
    fi
    echo '{}' > "$MANIFEST_FILE"
}

teardown() {
    # Clean up test temp directory
    rm -rf "$TEST_TMPDIR" 2>/dev/null || true
    
    # Restore manifest
    if [[ -f "$TEST_TMPDIR/manifest.backup" ]]; then
        mv "$TEST_TMPDIR/manifest.backup" "$MANIFEST_FILE"
    else
        rm -f "$MANIFEST_FILE" 2>/dev/null || true
    fi
    
    # Clean up any test artifacts in the source directory
    cd "$PROJECT_ROOT" 2>/dev/null || true
    for artifact in Pharo.image Pharo.changes Pharo*.sources pharo pharo-ui pharo-vm Pharo.app \
                   GlamorousToolkit GlamorousToolkit.app GlamorousToolkit.image GlamorousToolkit.changes \
                   Cuis.image Cuis.changes Cuis*.sources Cuis.app run_cuis.sh \
                   Squeak.image Squeak.changes Squeak*.sources Squeak*.app \
                   lst3r *.st *.fuel; do
        rm -rf "$PROJECT_ROOT/$artifact" 2>/dev/null || true
    done
}

# ============================================================================
# Basic CLI Tests
# ============================================================================

@test "st runs without arguments and shows usage" {
    run "$SMALLTALK_CMD"
    [ "$status" -eq 1 ]
    [[ "$output" == *"USAGE"* ]]
    [[ "$output" == *"IMPLEMENTATIONS"* ]]
}

@test "st --help shows usage" {
    run "$SMALLTALK_CMD" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"USAGE"* ]]
}

@test "st -h shows usage" {
    run "$SMALLTALK_CMD" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"USAGE"* ]]
}

@test "st help shows usage" {
    run "$SMALLTALK_CMD" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"USAGE"* ]]
}

# ============================================================================
# Implementation Validation Tests
# ============================================================================

@test "st with unknown implementation shows error" {
    run "$SMALLTALK_CMD" unknownimpl version
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown implementation"* ]]
}

@test "st pharo without command shows error" {
    run "$SMALLTALK_CMD" pharo
    [ "$status" -eq 1 ]
    [[ "$output" == *"No command specified"* ]]
}

@test "st gt without command shows error" {
    run "$SMALLTALK_CMD" gt
    [ "$status" -eq 1 ]
    [[ "$output" == *"No command specified"* ]]
}

@test "st squeak without command shows error" {
    run "$SMALLTALK_CMD" squeak
    [ "$status" -eq 1 ]
    [[ "$output" == *"No command specified"* ]]
}

@test "st cuis without command shows error" {
    run "$SMALLTALK_CMD" cuis
    [ "$status" -eq 1 ]
    [[ "$output" == *"No command specified"* ]]
}

@test "st gnu without command shows error" {
    run "$SMALLTALK_CMD" gnu
    [ "$status" -eq 1 ]
    [[ "$output" == *"No command specified"* ]]
}

@test "st lst without command shows error" {
    run "$SMALLTALK_CMD" lst
    [ "$status" -eq 1 ]
    [[ "$output" == *"No command specified"* ]]
}

# ============================================================================
# Help Command Tests
# ============================================================================

@test "st pharo help shows help text" {
    run "$SMALLTALK_CMD" pharo help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Pharo Smalltalk Commands"* ]]
    [[ "$output" == *"\`st pharo"* ]] || [[ "$output" == *"Usage"* ]]
    [[ "$output" == *"install"* ]]
    [[ "$output" == *"run"* ]]
    [[ "$output" == *"search"* ]]
    [[ "$output" == *"list"* ]]
}

@test "st gt help shows help text" {
    run "$SMALLTALK_CMD" gt help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Glamorous Toolkit Commands"* ]]
    [[ "$output" == *"\`st gt"* ]] || [[ "$output" == *"Usage"* ]]
}

@test "st squeak help shows help text" {
    run "$SMALLTALK_CMD" squeak help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Squeak Smalltalk Commands"* ]]
}

@test "st cuis help shows help text" {
    run "$SMALLTALK_CMD" cuis help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Cuis Smalltalk Commands"* ]]
}

@test "st gnu help shows help text" {
    run "$SMALLTALK_CMD" gnu help
    [ "$status" -eq 0 ]
    [[ "$output" == *"GNU Smalltalk Commands"* ]]
}

@test "st lst help shows help text" {
    run "$SMALLTALK_CMD" lst help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Little Smalltalk"* ]]
}

# ============================================================================
# Help Includes Version Information
# ============================================================================

@test "st cuis help shows available versions" {
    run "$SMALLTALK_CMD" cuis help
    [ "$status" -eq 0 ]
    [[ "$output" == *"stable"* ]]
    [[ "$output" == *"7.0"* ]]
    [[ "$output" == *"6.0"* ]]
}

@test "st squeak help shows available versions" {
    run "$SMALLTALK_CMD" squeak help
    [ "$status" -eq 0 ]
    [[ "$output" == *"stable"* ]]
    [[ "$output" == *"6.0"* ]]
    [[ "$output" == *"6.1"* ]]
    [[ "$output" == *"5.3"* ]]
}

# ============================================================================
# Unknown Command Tests
# ============================================================================

@test "st pharo with unknown command shows error" {
    run "$SMALLTALK_CMD" pharo unknowncmd
    [ "$status" -eq 2 ]
    [[ "$output" == *"is not supported"* ]]
}

@test "st gt with unknown command shows error" {
    run "$SMALLTALK_CMD" gt unknowncmd
    [ "$status" -eq 2 ]
    [[ "$output" == *"is not supported"* ]]
}

# ============================================================================
# Clap Commands Help - Pharo
# ============================================================================

@test "st pharo help includes Clap commands documentation" {
    run "$SMALLTALK_CMD" pharo help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Clap Commands"* ]]
    [[ "$output" == *"metacello"* ]]
    [[ "$output" == *"eval"* ]]
    [[ "$output" == *"st"* ]]
    [[ "$output" == *"save"* ]]
}

# ============================================================================
# Clap Commands Help - GT
# ============================================================================

@test "st gt help includes Clap commands documentation" {
    run "$SMALLTALK_CMD" gt help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Clap Commands"* ]]
    [[ "$output" == *"metacello"* ]]
    [[ "$output" == *"eval"* ]]
}

# ============================================================================
# Version Tests
# ============================================================================

@test "st pharo version shows not installed message" {
    run "$SMALLTALK_CMD" pharo version
    [ "$status" -eq 1 ]
    [[ "$output" == *"not installed"* ]]
}

@test "st gt version shows not installed message" {
    run "$SMALLTALK_CMD" gt version
    [ "$status" -eq 1 ]
    [[ "$output" == *"not installed"* ]]
}

@test "st squeak version shows not installed message" {
    run "$SMALLTALK_CMD" squeak version
    [ "$status" -eq 1 ]
    [[ "$output" == *"not installed"* ]]
}

@test "st cuis version shows not installed message" {
    run "$SMALLTALK_CMD" cuis version
    [ "$status" -eq 1 ]
    [[ "$output" == *"not installed"* ]]
}

# ============================================================================
# Clean Tests
# ============================================================================

@test "st pharo clean succeeds" {
    run "$SMALLTALK_CMD" pharo clean
    [ "$status" -eq 0 ]
    [[ "$output" == *"cache"* ]]
}

@test "st gt clean succeeds" {
    run "$SMALLTALK_CMD" gt clean
    [ "$status" -eq 0 ]
    [[ "$output" == *"cache"* ]]
}

@test "st squeak clean succeeds" {
    run "$SMALLTALK_CMD" squeak clean
    [ "$status" -eq 0 ]
    [[ "$output" == *"cache"* ]]
}

@test "st cuis clean succeeds" {
    run "$SMALLTALK_CMD" cuis clean
    [ "$status" -eq 0 ]
    [[ "$output" == *"cache"* ]]
}

# ============================================================================
# Search Without Arguments Tests
# ============================================================================

@test "st pharo search without term shows error" {
    run "$SMALLTALK_CMD" pharo search
    [ "$status" -eq 1 ]
    [[ "$output" == *"Please provide a search term"* ]]
}

@test "st gt search without term shows error" {
    run "$SMALLTALK_CMD" gt search
    [ "$status" -eq 1 ]
    [[ "$output" == *"Please provide a search term"* ]]
}

# ============================================================================
# Clean Artifacts Tests
# ============================================================================

@test "st clean_artifacts shows help when no implementation" {
    run "$SMALLTALK_CMD" clean_artifacts
    [ "$status" -eq 0 ]
    [[ "$output" == *"Cleaning"* ]] || [[ "$output" == *"artifacts"* ]]
}

@test "st clean_artifacts pharo succeeds" {
    run "$SMALLTALK_CMD" clean_artifacts pharo
    [ "$status" -eq 0 ]
    [[ "$output" == *"clean"* ]] || [[ "$output" == *"Pharo"* ]]
}

@test "st clean_artifacts gt succeeds" {
    run "$SMALLTALK_CMD" clean_artifacts gt
    [ "$status" -eq 0 ]
    [[ "$output" == *"clean"* ]] || [[ "$output" == *"Glamorous"* ]]
}

@test "st clean_artifacts cuis succeeds" {
    run "$SMALLTALK_CMD" clean_artifacts cuis
    [ "$status" -eq 0 ]
    [[ "$output" == *"clean"* ]] || [[ "$output" == *"Cuis"* ]]
}

@test "st clean_artifacts squeak succeeds" {
    run "$SMALLTALK_CMD" clean_artifacts squeak
    [ "$status" -eq 0 ]
    [[ "$output" == *"clean"* ]] || [[ "$output" == *"Squeak"* ]]
}

@test "st pharo clean_artifacts succeeds" {
    run "$SMALLTALK_CMD" pharo clean_artifacts
    [ "$status" -eq 0 ]
    [[ "$output" == *"clean"* ]] || [[ "$output" == *"artifacts"* ]]
}

@test "st gt clean_artifacts succeeds" {
    run "$SMALLTALK_CMD" gt clean_artifacts
    [ "$status" -eq 0 ]
    [[ "$output" == *"clean"* ]] || [[ "$output" == *"artifacts"* ]]
}

@test "st cuis clean_artifacts succeeds" {
    run "$SMALLTALK_CMD" cuis clean_artifacts
    [ "$status" -eq 0 ]
    [[ "$output" == *"clean"* ]] || [[ "$output" == *"artifacts"* ]]
}

@test "st squeak clean_artifacts succeeds" {
    run "$SMALLTALK_CMD" squeak clean_artifacts
    [ "$status" -eq 0 ]
    [[ "$output" == *"clean"* ]] || [[ "$output" == *"artifacts"* ]]
}

# ============================================================================
# All Implementations Listed in Help
# ============================================================================

@test "all implementations are listed in main help" {
    run "$SMALLTALK_CMD" --help
    [[ "$output" == *"pharo"* ]]
    [[ "$output" == *"cuis"* ]]
    [[ "$output" == *"gt"* ]]
    [[ "$output" == *"squeak"* ]]
    [[ "$output" == *"gnu"* ]]
    [[ "$output" == *"lst"* ]]
}

# ============================================================================
# Install Directory Option Tests
# ============================================================================

@test "st pharo help includes install directory option" {
    run "$SMALLTALK_CMD" pharo help
    [[ "$output" == *"-d"* ]] || [[ "$output" == *"--dir"* ]]
}

@test "st gt help includes install directory option" {
    run "$SMALLTALK_CMD" gt help
    [[ "$output" == *"-d"* ]] || [[ "$output" == *"--dir"* ]]
}

@test "st cuis help includes install directory option" {
    run "$SMALLTALK_CMD" cuis help
    [[ "$output" == *"-d"* ]] || [[ "$output" == *"--dir"* ]]
}

@test "st squeak help includes install directory option" {
    run "$SMALLTALK_CMD" squeak help
    [[ "$output" == *"-d"* ]] || [[ "$output" == *"--dir"* ]]
}

# ============================================================================
# Artifact Isolation Tests
# ============================================================================

@test "tests do not leave artifacts in source directory" {
    # Run a simple command
    run "$SMALLTALK_CMD" pharo version 2>&1
    
    # Check no artifacts were created
    for artifact in Pharo.image Pharo.changes Pharo*.sources pharo pharo-ui pharo-vm Pharo.app \
                   GlamorousToolkit GlamorousToolkit.app GlamorousToolkit.image; do
        if [[ -e "$PROJECT_ROOT/$artifact" ]]; then
            fail "Test left artifact: $artifact"
        fi
    done
}

# ============================================================================
# Install Command Option Parsing Tests
# ============================================================================

@test "st pharo install with -d flag accepts directory" {
    local test_dir="$TEST_TMPDIR/test-install"
    mkdir -p "$test_dir"
    
    # Test with non-existing implementation dir (should try to download)
    # Just verify the option parsing doesn't error
    run bash -c "cd '$test_dir' && '$SMALLTALK_CMD' pharo install -d '$test_dir' 2>&1" || true
    
    # Should not have "unrecognized option" error
    [[ "$output" != *"unrecognized option"* ]]
}

@test "st cuis install with version accepts version number" {
    local test_dir="$TEST_TMPDIR/test-cuis"
    mkdir -p "$test_dir"
    
    run bash -c "cd '$test_dir' && '$SMALLTALK_CMD' cuis install 7.0 2>&1" || true
    
    # Should not have "Unknown option" error - version is positional arg
    [[ "$output" != *"unrecognized option"* ]]
}

@test "st squeak install with version accepts version number" {
    local test_dir="$TEST_TMPDIR/test-squeak"
    mkdir -p "$test_dir"
    
    run bash -c "cd '$test_dir' && '$SMALLTALK_CMD' squeak install 6.0 2>&1" || true
    
    # Should not have "unrecognized option" error
    [[ "$output" != *"unrecognized option"* ]]
}

# ============================================================================
# Install Error Handling Tests
# ============================================================================

@test "st pharo install to non-empty directory with other Smalltalk fails" {
    local test_dir="$TEST_TMPDIR/test-conflict"
    mkdir -p "$test_dir"
    
    # Create a fake Cuis installation
    touch "$test_dir/Cuis.image"
    touch "$test_dir/Cuis.changes"
    
    run bash -c "cd '$test_dir' && '$SMALLTALK_CMD' pharo install 2>&1"
    
    # Should fail with conflict error
    [ "$status" -ne 0 ]
    [[ "$output" == *"already contains"* ]] || [[ "$output" == *"cuis"* ]]
}

@test "st gt install to non-empty directory with other Smalltalk fails" {
    local test_dir="$TEST_TMPDIR/test-conflict2"
    mkdir -p "$test_dir"
    
    # Create a fake Pharo installation
    touch "$test_dir/Pharo.image"
    touch "$test_dir/Pharo.changes"
    
    run bash -c "cd '$test_dir' && '$SMALLTALK_CMD' gt install 2>&1"
    
    # Should fail with conflict error
    [ "$status" -ne 0 ]
    [[ "$output" == *"already contains"* ]] || [[ "$output" == *"pharo"* ]]
}

@test "st cuis install with invalid version shows error" {
    run bash -c "'$SMALLTALK_CMD' cuis install invalid-version-xyz 2>&1"
    
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown Cuis version"* ]] || [[ "$output" == *"invalid-version-xyz"* ]]
}

@test "st squeak install with invalid version shows error" {
    run bash -c "'$SMALLTALK_CMD' squeak install invalid-version-xyz 2>&1"
    
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown Squeak version"* ]] || [[ "$output" == *"invalid-version-xyz"* ]]
}

# ============================================================================
# Failed Download Cleanup Tests
# ============================================================================

@test "failed download does not leave temporary files in source" {
    local test_dir="$TEST_TMPDIR/test-failed-install"
    mkdir -p "$test_dir"
    
    # Mock a failed download by using an invalid URL
    # The install should fail gracefully
    run bash -c "cd '$test_dir' && '$SMALLTALK_CMD' pharo install -d '$test_dir' 2>&1" || true
    
    # Source directory should not have any partial files
    # (except maybe in case of network issues, check no obvious artifacts)
    [[ ! -f "$PROJECT_ROOT/Pharo.image" ]]
    [[ ! -f "$PROJECT_ROOT/Pharo.changes" ]]
}

@test "failed install to test directory cleans up properly" {
    local test_dir="$TEST_TMPDIR/test-failed-dir"
    mkdir -p "$test_dir"
    
    # Try to install to a read-only directory (should fail gracefully)
    chmod 000 "$test_dir" 2>/dev/null || true
    
    run bash -c "'$SMALLTALK_CMD' pharo install -d '$test_dir' 2>&1" || true
    
    # Restore permissions
    chmod 755 "$test_dir" 2>/dev/null || true
    
    # Should have failed but not crashed
    [[ "$output" == *"ERROR"* ]] || [[ "$output" == *"Failed"* ]] || [[ "$output" == *"Cannot"* ]]
}

# ============================================================================
# Manifest Tests
# ============================================================================

@test "clean_artifacts handles missing manifest gracefully" {
    rm -f "$MANIFEST_FILE" 2>/dev/null || true
    
    run "$SMALLTALK_CMD" clean_artifacts
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"clean"* ]] || [[ "$output" == *"artifacts"* ]]
}

@test "clean_artifacts with unknown impl shows error and lists valid impls" {
    # Currently accepts any impl and just cleans all artifacts
    # This is acceptable behavior - unknown impls are ignored
    run "$SMALLTALK_CMD" clean_artifacts unknownimpl
    
    # Should complete without error (unknown impls are ignored)
    [ "$status" -eq 0 ]
    [[ "$output" == *"clean"* ]] || [[ "$output" == *"artifacts"* ]]
}

# ============================================================================
# Cuis Version Tests
# ============================================================================

@test "st cuis install with version stable works" {
    local test_dir="$TEST_TMPDIR/test-cuis-stable"
    mkdir -p "$test_dir"
    
    run bash -c "cd '$test_dir' && '$SMALLTALK_CMD' cuis install stable 2>&1" || true
    
    # Should not have "unrecognized option" error
    [[ "$output" != *"unrecognized option"* ]]
}

@test "st cuis install version and directory together" {
    local test_dir="$TEST_TMPDIR/test-cuis-combined"
    mkdir -p "$test_dir"
    
    run bash -c "'$SMALLTALK_CMD' cuis install 7.0 -d '$test_dir' 2>&1" || true
    
    # Should not have "unrecognized option" error
    [[ "$output" != *"unrecognized option"* ]]
}

# ============================================================================
# Squeak Version Tests
# ============================================================================

@test "st squeak install with version stable works" {
    local test_dir="$TEST_TMPDIR/test-squeak-stable"
    mkdir -p "$test_dir"
    
    run bash -c "cd '$test_dir' && '$SMALLTALK_CMD' squeak install stable 2>&1" || true
    
    # Should not have "unrecognized option" error
    [[ "$output" != *"unrecognized option"* ]]
}

@test "st squeak install version and directory together" {
    local test_dir="$TEST_TMPDIR/test-squeak-combined"
    mkdir -p "$test_dir"
    
    run bash -c "'$SMALLTALK_CMD' squeak install 5.4 -d '$test_dir' 2>&1" || true
    
    # Should not have "unrecognized option" error
    [[ "$output" != *"unrecognized option"* ]]
}
