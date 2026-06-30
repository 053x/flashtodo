#!/usr/bin/env bash
set -euo pipefail

project_file="FlashTodo.xcodeproj/project.pbxproj"
mode="${1:-build}"

usage() {
  echo "Usage: scripts/bump-version.sh [build|major|minor|patch|x.y.z]"
}

if [[ ! -f "$project_file" ]]; then
  echo "error: run this script from the repository root" >&2
  exit 1
fi

current_version="$(
  grep -m 1 '^[[:space:]]*MARKETING_VERSION = ' "$project_file" \
    | sed -E 's/.*MARKETING_VERSION = ([0-9]+)\.([0-9]+)\.([0-9]+);/\1.\2.\3/'
)"

if [[ ! "$current_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: unable to read semantic MARKETING_VERSION from $project_file" >&2
  exit 1
fi

IFS='.' read -r major minor patch <<< "$current_version"

case "$mode" in
  build)
    ;;
  major)
    major=$((major + 1))
    minor=0
    patch=0
    ;;
  minor)
    minor=$((minor + 1))
    patch=0
    ;;
  patch)
    patch=$((patch + 1))
    ;;
  [0-9]*.[0-9]*.[0-9]*)
    IFS='.' read -r major minor patch <<< "$mode"
    ;;
  *)
    usage
    exit 1
    ;;
esac

next_version="$major.$minor.$patch"

current_build="$(
  grep -m 1 '^[[:space:]]*CURRENT_PROJECT_VERSION = ' "$project_file" \
    | sed -E 's/.*CURRENT_PROJECT_VERSION = ([0-9]+);/\1/'
)"

if [[ ! "$current_build" =~ ^[0-9]+$ ]]; then
  echo "error: unable to read numeric CURRENT_PROJECT_VERSION from $project_file" >&2
  exit 1
fi

next_build=$((current_build + 1))

perl -0pi -e "s/MARKETING_VERSION = [0-9]+\.[0-9]+\.[0-9]+;/MARKETING_VERSION = $next_version;/g" "$project_file"
perl -0pi -e "s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = $next_build;/g" "$project_file"

echo "Bumped FlashTodo $current_version ($current_build) -> $next_version ($next_build)"
