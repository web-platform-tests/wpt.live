#!/bin/bash

# Create, update, and delete git worktrees in the `submissions/` subdirectory
# based on the refs available in the remote repository named "upstream".
#
# Specifically, consider refs in the namespaces `prs-open/*` and
# `prs-labeled-for-preview/*`. For all refs with identical names in both
# namespaces, ensure that a worktree has been created and checked out to the
# relevant revision. Remove any previously-created worktrees for which the
# above condition does not hold.

set -euo pipefail

git fetch --prune origin "+refs/prs-open/*:refs/prs-open/*"
git fetch --prune origin "+refs/prs-labeled-for-preview/*:refs/prs-labeled-for-preview/*"

open=$(
  git show-ref | grep refs/prs-open/ | cut -f 3 -d / | sort
)
labeled=$(
  git show-ref | grep refs/prs-labeled-for-preview/ | cut -f 3 -d / | sort
)
active=$(comm -12 <(echo "${open}") <(echo "${labeled}"))

echo open:    $(echo "${open}" | wc --lines)
echo labeled: $(echo "${labeled}" | wc --lines)
echo active:  $(echo "${active}" | wc --lines)

# The following pipeline tolerates the exit status of "1" from grep since it
# indicates that no match was found, and that is not an exceptional case in
# this context.
directories=$(
  git worktree list --porcelain | \
    (grep "worktree ${PWD}/submissions" || test $? = '1') | \
    sed 's/^.*submissions\///g' | \
    sort
)

to_delete=$(comm -13 <(echo "${active}") <(echo "${directories}"))
to_update=$(comm -12 <(echo "${active}") <(echo "${directories}"))
to_create=$(comm -23 <(echo "${active}") <(echo "${directories}"))

echo to delete: ${to_delete}
echo to update: ${to_update}
echo to create: ${to_create}

for name in ${to_delete}; do
  # The worktree may be locked if the `add` command which created it was
  # interrupted (e.g. due to reaching disk capacity). Unlock the worktree
  # (tolerating failure in cases where the worktree is not locked), and remove
  # with the `--force` flag to handle cases where the worktree is dirty.
  git worktree unlock submissions/${name} || true
  git worktree remove --force submissions/${name}
done

for name in ${to_update}; do
  (cd submissions/${name} && git checkout refs/prs-open/${name})
done

for name in ${to_create}; do
  git worktree add submissions/${name} refs/prs-open/${name}
done

git worktree prune
git gc
