#!/bin/bash

# Create, update, and delete git worktrees based on the refs available in the
# remote repository named "upstream".
#
# Specifically, consider refs in the namespaces `prs-open/*` and
# `prs-trusted-for-preview/*`. For all refs with identical names in both
# namespaces, ensure that a worktree has been created and checked out to the
# relevant revision. Remove any previously-created worktrees for which the
# above condition does not hold.

set -euo pipefail

# GNU "grep" typically reports the absence of a match with a non-zero exit
# status. From the GNU/Linux manual page, grep(1):
#
# > Normally the exit status is 0 if a line is selected, 1 if no lines were
# > selected, and 2 if an error occurred.
#
# However, in the context of this script, such a result is not exceptional and
# should not cause failure (e.g. when there are currently no pull requests
# which have been trusted for preview). The following function tolerates the
# condition without masking errors.
function grep_tolerate_none {
  grep "$@" || test $? = '1'
}

git fetch --prune origin "+refs/prs-open/*:refs/prs-open/*"
git fetch --prune origin "+refs/prs-trusted-for-preview/*:refs/prs-trusted-for-preview/*"

open=$(
  git show-ref | grep_tolerate_none refs/prs-open/ | \
    cut -f 3 -d / | \
    sort
)
trusted=$(
  git show-ref | grep_tolerate_none refs/prs-trusted-for-preview/ | \
    cut -f 3 -d / | \
    sort
)
active=$(comm -12 <(echo "${open}") <(echo "${trusted}"))

echo open:    $(echo "${open}" | wc --lines)
echo trusted: $(echo "${trusted}" | wc --lines)
echo active:  $(echo "${active}" | wc --lines)

directories=$(
  git worktree list --porcelain | \
    grep_tolerate_none -E "worktree ${PWD}/[0-9]" | \
    sed "s%^worktree ${PWD}/%%g" | \
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
  git worktree unlock ${name} 2> /dev/null || \
    echo Worktree \'${name}\' is not locked
  git worktree remove --force ${name}
done

for name in ${to_update}; do
  (cd ${name} && git checkout refs/prs-open/${name})
done

for name in ${to_create}; do
  git worktree add ${name} refs/prs-open/${name}
done

git worktree prune
git gc
