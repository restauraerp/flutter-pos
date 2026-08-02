#!/usr/bin/env bash
#
# Single source of truth for the application version.
#
# The version lives in exactly one place -- the `version:` line of pubspec.yaml --
# and every other consumer (git tag, Android versionName/versionCode, the APK
# filename, the GitHub release) is derived from it. Nothing else may declare a
# version of its own.
#
# Format: MAJOR.MINOR.PATCH+BUILD
#   MAJOR   unpadded integer
#   MINOR   zero-padded to two digits
#   PATCH   zero-padded to two digits
#   BUILD   monotonic integer, never reset -- becomes the Android versionCode
#
# Example: 1.00.02+3  ->  tag v1.00.02, versionName 1.00.02, versionCode 3
#
# The zero padding is intentional and matches the existing v1.00.00 / v1.00.01
# tags. Dart's pub_semver preserves the literal text of a parsed version, so
# `flutter build` emits "1.00.02" verbatim as the versionName.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBSPEC="$PROJECT_ROOT/pubspec.yaml"

die() {
    echo "error: $*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Usage: tool/version.sh <command> [args]

  current            Print the full version, e.g. 1.00.02+3
  name               Print the version name only, e.g. 1.00.02
  code               Print the build number only, e.g. 3
  tag                Print the git tag, e.g. v1.00.02
  next <part>        Print what major|minor|patch would bump to, without writing
  bump <part>        Bump major|minor|patch (build always +1), write pubspec.yaml,
                     print the new version name
  set <name> [code]  Force a specific version, e.g. `set 1.00.01 1`
  check <tag>        Exit non-zero unless <tag> matches the pubspec version
EOF
}

# ---------------------------------------------------------------- read

read_version() {
    [ -f "$PUBSPEC" ] || die "pubspec.yaml not found at $PUBSPEC"

    local raw
    raw="$(sed -n 's/^version:[[:space:]]*\([^[:space:]#]*\).*/\1/p' "$PUBSPEC" | head -n 1)"

    [ -n "$raw" ] || die "no 'version:' line found in $PUBSPEC"
    echo "$raw"
}

# Splits "1.00.02+3" into the globals MAJOR MINOR PATCH BUILD.
# 10# forces base-10 so zero-padded components are not read as octal.
parse_version() {
    local raw="$1" name build

    case "$raw" in
        *+*)
            name="${raw%%+*}"
            build="${raw##*+}"
            ;;
        *)
            die "version '$raw' has no +build number; expected MAJOR.MM.PP+BUILD"
            ;;
    esac

    [[ "$name" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
        || die "version name '$name' is not MAJOR.MINOR.PATCH"
    [[ "$build" =~ ^[0-9]+$ ]] \
        || die "build number '$build' is not an integer"

    MAJOR=$((10#${name%%.*}))
    PATCH=$((10#${name##*.}))
    local middle="${name#*.}"
    MINOR=$((10#${middle%%.*}))
    BUILD=$((10#$build))
}

# Reads pubspec and populates MAJOR MINOR PATCH BUILD. Assigning through a local
# first is deliberate: `set -e` aborts on a failed assignment, but a failed
# command substitution used directly as an argument would be swallowed.
load_version() {
    local raw
    raw="$(read_version)"
    parse_version "$raw"
}

format_name() {
    printf '%d.%02d.%02d' "$MAJOR" "$MINOR" "$PATCH"
}

format_full() {
    printf '%s+%d' "$(format_name)" "$BUILD"
}

# ---------------------------------------------------------------- write

write_version() {
    local new="$1"
    local tmp="$PUBSPEC.tmp.$$"

    # awk rather than `sed -i` so this also works with BSD sed on macOS. Only the
    # first top-level `version:` line is rewritten -- anchoring to the start of
    # the line keeps any nested `version:` key inside another mapping untouched.
    awk -v new="version: $new" '
        !done && /^version:/ { print new; done = 1; next }
        { print }
        END { if (!done) { print "no version: line found" > "/dev/stderr"; exit 1 } }
    ' "$PUBSPEC" > "$tmp"

    mv "$tmp" "$PUBSPEC"

    local written
    written="$(read_version)"
    [ "$written" = "$new" ] || die "pubspec write failed: expected $new, got $written"
}

# ---------------------------------------------------------------- commands

# Applies the bump to the in-memory MAJOR/MINOR/PATCH/BUILD without touching
# pubspec.yaml, so `next` and `bump` can never disagree about the result.
apply_bump() {
    local part="${1:-patch}"

    load_version

    case "$part" in
        major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
        minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
        patch) PATCH=$((PATCH + 1)) ;;
        *) die "unknown version part '$part'; expected major, minor or patch" ;;
    esac

    (( MINOR <= 99 )) || die "minor $MINOR exceeds 99; the two-digit scheme is out of room"
    (( PATCH <= 99 )) || die "patch $PATCH exceeds 99; bump the minor instead"

    BUILD=$((BUILD + 1))
}

cmd_next() {
    apply_bump "${1:-patch}"
    format_name
}

cmd_bump() {
    apply_bump "${1:-patch}"
    write_version "$(format_full)"
    format_name
}

cmd_set() {
    local name="${1:-}" build="${2:-}"

    [ -n "$name" ] || die "set requires a version name, e.g. 'set 1.00.01 1'"

    if [ -z "$build" ]; then
        load_version
        build="$BUILD"
    fi

    parse_version "${name#v}+$build"
    write_version "$(format_full)"
    format_name
}

cmd_check() {
    local tag="${1:-}"

    [ -n "$tag" ] || die "check requires a tag, e.g. 'check v1.00.02'"

    load_version

    local expected
    expected="v$(format_name)"

    if [ "$tag" != "$expected" ]; then
        die "tag '$tag' does not match pubspec version '$expected'. Release the version with tool/version.sh bump instead of tagging by hand."
    fi

    echo "$tag matches pubspec version $(format_full)"
}

main() {
    local command="${1:-}"
    shift || true

    case "$command" in
        current) load_version; format_full; echo ;;
        name)    load_version; format_name; echo ;;
        code)    load_version; echo "$BUILD" ;;
        tag)     load_version; printf 'v%s\n' "$(format_name)" ;;
        next)    cmd_next "$@"; echo ;;
        bump)    cmd_bump "$@"; echo ;;
        set)     cmd_set "$@"; echo ;;
        check)   cmd_check "$@" ;;
        -h|--help|help|"") usage ;;
        *) usage >&2; die "unknown command '$command'" ;;
    esac
}

main "$@"
