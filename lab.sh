#!/bin/bash
# pod lab driver.  bash lab.sh create | prs | wait | approve <pr> | report | delete
set -euo pipefail
LAB="$(cd "$(dirname "$0")" && pwd)"; REPO=ajpasco/pod-lab-20261024; cd "$LAB"
TRAIL="Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"

case "${1:-}" in
create)
  gh repo create "$REPO" --public --source=. --remote=origin --push \
    --description "Disposable lab for pod, 2026-10-24. Safe to delete."
  gh repo edit "$REPO" --enable-auto-merge --delete-branch-on-merge
  cat > /tmp/pod-lab-protection.json <<'JSON'
{"required_status_checks":{"strict":false,"checks":[{"context":"pod-gate","app_id":15368}]},"enforce_admins":true,"required_pull_request_reviews":null,"restrictions":null,"allow_force_pushes":false,"allow_deletions":false}
JSON
  gh api -X PUT "repos/$REPO/branches/main/protection" --input /tmp/pod-lab-protection.json \
    -q '{required: .required_status_checks.checks, admins_bound: .enforce_admins.enabled, force_push: .allow_force_pushes.enabled}'
  echo "created: https://github.com/$REPO"
  ;;
prs)
  branch() { git checkout -q main; git checkout -q -b "$1"; }
  finish() { git add -A; git commit -q -m "$1

$TRAIL"; git push -q -u origin HEAD; }
  # A. A story that stays in scope and passes: merges with nobody clicking.
  branch story/1
  cat > app/calc.js <<'JS'
export function add(a, b) {
  return a + b;
}

export function subtract(a, b) {
  return a - b;
}
JS
  finish "story 1: add subtract"
  A=$(gh pr create --title "A. story 1: subtract (in scope, passes)" --body "Expected: pod-gate success, auto-merge, no human." --json number -q .number 2>/dev/null || gh pr create --title "A. story 1: subtract (in scope, passes)" --body "Expected: pod-gate success, auto-merge, no human." | sed -n 's#.*/pull/##p')
  gh pr merge "$A" --auto --squash
  # B. A builder that edits the test to always pass and breaks the app: the verdict ignores its test.
  branch story/1-cheat
  cat > eval/test.js <<'JS'
import test from 'node:test';
test('T-001 add returns the sum', () => {});
JS
  cat > app/calc.js <<'JS'
export function add(a, b) {
  return 0;
}
JS
  finish "story 1 cheat: edit the test, break the app"
  B=$(gh pr create --title "B. story 1 cheat: test edited, app broken" --body "Expected: pod-gate failure on main's eval, and waiting for approval because eval/ changed." | sed -n 's#.*/pull/##p')
  # C. The founder's own eval change: waits for the status, then merges without a re-run.
  branch eval/negative-test
  cat > eval/test-negative.js <<'JS'
import test from 'node:test';
import assert from 'node:assert/strict';
import { add } from '../app/calc.js';

test('T-002 add handles a negative', () => {
  assert.equal(add(-1, 1), 0);
});
JS
  finish "eval: a negative case for add"
  C=$(gh pr create --title "C. eval: negative case (needs the founder)" --body "Expected: pod-gate failure 'waiting for the founder', then success and auto-merge after pod-approve.sh." | sed -n 's#.*/pull/##p')
  gh pr merge "$C" --auto --squash
  # D. A story that touches a file outside its scope.
  branch story/1-escape
  printf '\nEdited by a story that may only touch app/.\n' >> README.md
  finish "story 1 escape: outside scope"
  D=$(gh pr create --title "D. story 1 escape: README outside scope" --body "Expected: pod-gate failure on scope." | sed -n 's#.*/pull/##p')
  git checkout -q main
  echo "A=$A B=$B C=$C D=$D" | tee "$LAB/.prs"
  ;;
wait)
  # until every open pull request's head carries a pod-gate check run, or 8 minutes
  for i in $(seq 1 48); do
    missing=0
    for sha in $(gh pr list --repo "$REPO" --state open --json headRefOid -q '.[].headRefOid'); do
      n=$(gh api "repos/$REPO/commits/$sha/check-runs" -q '[.check_runs[] | select(.name=="pod-gate" and .status=="completed")] | length')
      [ "$n" -ge 1 ] || missing=1
    done
    [ $missing = 0 ] && { echo "every open pull request has a pod-gate verdict"; exit 0; }
    sleep 10
  done
  echo "timed out waiting for pod-gate"; exit 1
  ;;
approve)
  sh "$LAB/pod-approve.sh" "$2"
  ;;
repair)
  # Main's exam is broken, so no pull request can pass pod-gate, the fix included: every pull
  # request is judged by main's copy. The one recovery GitHub offers is an administrator lifting
  # administrator enforcement for the moment of one push. It is restored on exit whatever happens,
  # and GitHub's audit log records both changes.
  git checkout -q main
  restore() { gh api -X POST "repos/$REPO/branches/main/protection/enforce_admins" -q '"administrators bound again: \(.enabled)"'; }
  trap restore EXIT
  gh api -X DELETE "repos/$REPO/branches/main/protection/enforce_admins" > /dev/null && echo "administrator enforcement lifted"
  git push -q origin main && echo "pushed $(git rev-parse --short HEAD) to main: $(git log -1 --format=%s)"
  ;;
wait-after)
  # until every open pull request's newest pod-gate verdict started after the given UTC moment
  T="$2"
  for i in $(seq 1 48); do
    missing=0
    for sha in $(gh pr list --repo "$REPO" --state open --json headRefOid -q '.[].headRefOid'); do
      latest=$(gh api "repos/$REPO/commits/$sha/check-runs" -q '[.check_runs[] | select(.name=="pod-gate" and .status=="completed")] | sort_by(.started_at) | last | .started_at // empty')
      { [ -n "$latest" ] && [ "$latest" \> "$T" ]; } || missing=1
    done
    [ $missing = 0 ] && { echo "every open pull request has a pod-gate verdict newer than $T"; exit 0; }
    sleep 10
  done
  echo "timed out waiting for new verdicts"; exit 1
  ;;
report)
  gh pr list --repo "$REPO" --state all --json number,title,state,mergedAt,headRefOid,autoMergeRequest -q '.[]' | while read -r row; do
    n=$(jq -r .number <<<"$row"); sha=$(jq -r .headRefOid <<<"$row")
    echo "== #$n $(jq -r .title <<<"$row")"
    echo "   state=$(jq -r .state <<<"$row") merged=$(jq -r '.mergedAt // "no"' <<<"$row") auto=$(jq -r 'if .autoMergeRequest then "on" else "off" end' <<<"$row")"
    gh api "repos/$REPO/commits/$sha/check-runs" -q '.check_runs[] | select(.name=="pod-gate") | "   pod-gate: \(.conclusion) (\(.started_at))\n" + (.output.summary | split("\n") | map("     " + .) | join("\n"))'
  done
  ;;
delete)
  gh repo delete "$REPO" --yes
  ;;
*)
  echo "usage: bash lab.sh create | prs | wait | wait-after <utc> | approve <pr> | repair | report | delete"; exit 2;;
esac
