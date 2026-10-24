#!/bin/sh
# The founder's approval from a terminal. The console's button does exactly this call.
#   pod-approve.sh <pr number>
set -e
PR="$1"; REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
SHA=$(gh pr view "$PR" --repo "$REPO" --json headRefOid -q .headRefOid)
WHO=$(gh api user -q .login)
gh api "repos/$REPO/statuses/$SHA" --method POST \
  -f state=success -f context=pod/approval \
  -f description="Approved by $WHO at $(date -u +%FT%TZ)" > /dev/null
echo "pod/approval = success on $SHA (pull request #$PR), by $WHO"
