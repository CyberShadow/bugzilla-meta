#!/bin/bash
set -eEuo pipefail

# Upstream some commits as a pull request.
# Usage: ./upstream.sh branch-name-to-create commit1 [commit2...]

branch=$1
shift
commits=("$@")

cd src

git checkout -B "$branch" harmony/master

for commit in "${commits[@]}"
do
	git cherry-pick "$commit"
	EDITOR="$(dirname "$0")"/../upstream-editor.sh git commit --amend
done

prove t
git push --force-with-lease dlang "$branch"
xdg-open "https://github.com/bugzilla/harmony/compare/master...CyberShadow:$branch?expand=1"

git checkout dlang
