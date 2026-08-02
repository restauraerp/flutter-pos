#!/usr/bin/env bash
#
# Finishes the git flow release opened by ./release.sh.
#
#   ./publish.sh ["Release message"]
#
# Merges the release branch into master and develop, tags it vX.YY.ZZ, and pushes
# all three refs. Pushing the tag is what triggers .github/workflows/release.yml,
# which builds the APK and attaches it to a GitHub release.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

VERSION_TOOL="./tool/version.sh"

die() {
    echo "error: $*" >&2
    exit 1
}

command -v git >/dev/null || die "git is not installed"
git flow version >/dev/null 2>&1 || die "git flow is not installed (apt install git-flow)"
[ -x "$VERSION_TOOL" ] || die "$VERSION_TOOL is missing or not executable"

MASTER_BRANCH="$(git config --get gitflow.branch.master || echo master)"
DEVELOP_BRANCH="$(git config --get gitflow.branch.develop || echo develop)"
RELEASE_PREFIX="$(git config --get gitflow.prefix.release || echo release/)"

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

case "$CURRENT_BRANCH" in
    "$RELEASE_PREFIX"*) ;;
    *) die "expected to be on a '${RELEASE_PREFIX}*' branch, but you are on '$CURRENT_BRANCH'. Run ./release.sh first." ;;
esac

git diff-index --quiet HEAD -- \
    || die "working tree has uncommitted changes; commit or stash them first"

# The branch is release/vX.YY.ZZ and git flow tags it with the branch's version
# part, so the tag is exactly that suffix.
VERSION="$("$VERSION_TOOL" name)"
TAG="v$VERSION"
BRANCH_TAG="${CURRENT_BRANCH#"$RELEASE_PREFIX"}"

[ "$BRANCH_TAG" = "$TAG" ] \
    || die "branch '$CURRENT_BRANCH' does not match the pubspec version '$TAG'"

if git rev-parse --verify --quiet "refs/tags/$TAG" >/dev/null; then
    die "tag $TAG already exists locally"
fi

RELEASE_MESSAGE="${1:-Release $TAG}"

echo "==> Finishing release $TAG..."
# -m supplies the tag message so git flow never opens an editor.
git flow release finish -m "$RELEASE_MESSAGE" "$BRANCH_TAG"

echo "==> Pushing $DEVELOP_BRANCH..."
git checkout "$DEVELOP_BRANCH"
git push origin "$DEVELOP_BRANCH"

echo "==> Pushing $MASTER_BRANCH..."
git checkout "$MASTER_BRANCH"
git push origin "$MASTER_BRANCH"

git checkout "$DEVELOP_BRANCH"

echo "==> Pushing tag $TAG..."
git push origin "refs/tags/$TAG"

cat <<EOF

Released $TAG.

The tag push triggers the "Release APK" workflow. When it finishes, the
installable APK is attached to the release:

    https://github.com/restauraerp/flutter-pos/releases/tag/$TAG

Watch it with: gh run watch
EOF
