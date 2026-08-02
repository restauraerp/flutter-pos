#!/usr/bin/env bash
#
# Starts a git flow release.
#
#   ./release.sh [patch|minor|major]      (default: patch)
#
# Bumps the version in pubspec.yaml, opens release/vX.YY.ZZ, commits the bump and
# publishes the branch. Nothing is tagged yet -- run ./publish.sh once the release
# branch has been checked, and that is what triggers the APK build.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

PART="${1:-patch}"
VERSION_TOOL="./tool/version.sh"

die() {
    echo "error: $*" >&2
    exit 1
}

case "$PART" in
    patch|minor|major) ;;
    *) die "usage: ./release.sh [patch|minor|major]" ;;
esac

# ---------------------------------------------------------------- preflight

command -v git >/dev/null || die "git is not installed"
git flow version >/dev/null 2>&1 || die "git flow is not installed (apt install git-flow)"
[ -x "$VERSION_TOOL" ] || die "$VERSION_TOOL is missing or not executable"

DEVELOP_BRANCH="$(git config --get gitflow.branch.develop || echo develop)"
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

[ "$CURRENT_BRANCH" = "$DEVELOP_BRANCH" ] \
    || die "releases start from '$DEVELOP_BRANCH', but you are on '$CURRENT_BRANCH'"

# A dirty tree would get swept into the version-bump commit.
git diff-index --quiet HEAD -- \
    || die "working tree has uncommitted changes; commit or stash them first"

echo "==> Fetching remote state..."
git fetch --tags --prune origin

# Refuse to build on a stale develop -- otherwise the release branch silently
# omits commits that are already on the remote.
if git rev-parse --verify --quiet "origin/$DEVELOP_BRANCH" >/dev/null; then
    BEHIND="$(git rev-list --count "HEAD..origin/$DEVELOP_BRANCH")"
    [ "$BEHIND" -eq 0 ] \
        || die "'$DEVELOP_BRANCH' is $BEHIND commit(s) behind origin; pull first"
fi

# ---------------------------------------------------------------- version

CURRENT_VERSION="$("$VERSION_TOOL" current)"
NEW_VERSION="$("$VERSION_TOOL" next "$PART")"
TAG="v$NEW_VERSION"

if git rev-parse --verify --quiet "refs/tags/$TAG" >/dev/null; then
    die "tag $TAG already exists; the pubspec version is out of sync with the tags"
fi

echo "==> Releasing $PART: $CURRENT_VERSION -> $NEW_VERSION (tag $TAG)"

# ---------------------------------------------------------------- release

echo "==> Starting git flow release $TAG..."
git flow release start "$TAG"

echo "==> Bumping pubspec.yaml..."
"$VERSION_TOOL" bump "$PART" >/dev/null

# Guard against the bump and the branch name drifting apart.
WRITTEN="$("$VERSION_TOOL" name)"
[ "$WRITTEN" = "$NEW_VERSION" ] \
    || die "pubspec says $WRITTEN but the release branch is $TAG"

git add pubspec.yaml
git commit -m "chore(release): version bumped to $NEW_VERSION"

echo "==> Publishing the release branch..."
git flow release publish "$TAG"

cat <<EOF

Release $TAG is open on release/$TAG.
pubspec.yaml is now $("$VERSION_TOOL" current) (versionName $NEW_VERSION, versionCode $("$VERSION_TOOL" code)).

Next: verify the branch, then run

    ./publish.sh "Release $TAG"

which finishes the release, pushes the $TAG tag, and triggers the APK build.
EOF
