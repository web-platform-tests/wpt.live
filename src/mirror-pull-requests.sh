#!/bin/bash

set -e

remote=origin

git fetch --prune ${remote} "+refs/prs-open/*:refs/prs-open/*"
git fetch --prune ${remote} "+refs/prs-labeled-for-preview/*:refs/prs-labeled-for-preview/*"

open=$(
  git show-ref | grep refs/prs-open/ | cut -f 3 -d / | sort
)
labeled=$(
  git show-ref | grep refs/prs-labeled-for-preview/ | cut -f 3 -d / | sort
)
active=$(comm -12 <(echo "${open}") <(echo "${labeled}"))
echo open:    ${open}
echo labeled: ${labeled}
echo active:  ${active}

directories=$(
  git worktree list --porcelain | \
    grep "worktree $PWD/submissions" | \
    sed 's/^.*submissions\///g' | \
    sort
)

to_create=$(comm -23 <(echo "${active}") <(echo "${directories}"))
to_update=$(comm -12 <(echo "${active}") <(echo "${directories}"))
to_delete=$(comm -13 <(echo "${active}") <(echo "${directories}"))

echo to update: ${to_update}
echo to create: ${to_create}
echo to delete: ${to_delete}

for name in ${to_create}; do
  git worktree add ${tag} submissions/${name}
done

for name in ${to_update}; do
  (cd submissions/${name} && git checkout refs/prs-open/${name})
done

for name in ${to_delete}; do
  git worktree remove submissions/${name}
done

git worktree prune
git gc
