#!/bin/sh
# The conventions step (docs/orchestrator/PRACTICES.md, section C). It is not a row: it asserts no
# business outcome and traces to no requirement. It runs pinned tools from here against app/ and
# fails the acceptance tests when one of them fails. Its tools and their configuration live under
# eval/, so a builder can change them no more than it can change a test, and every tool is passed
# its configuration explicitly so that nothing a builder puts under app/ is read as configuration.
#
# Two rules this file keeps: an empty app/ has nothing to check and passes (the rows, not this
# step, fail by absence); and a tool is added only once it runs clean on the trunk's app/ as it
# stands, so that the next story is never blocked for a reason it did not cause.
set -eu
cd "$(dirname "$0")/.."
ROOT=$(pwd)
if [ ! -d app ] || [ -z "$(find app -type f | head -1)" ]; then
  echo "[conventions] app/ is empty; nothing to check"
  exit 0
fi

# Forbidden names: no file under app/ may name the acceptance tests' runner, their reporter or the
# folder their reports are written to (eval/conventions/forbidden-in-app.txt). A build that can
# reach its own report can grade itself; this refuses the lazy version, by name, and the fresh
# reader and the eval plan's coverage rules answer the rest. It runs first because it is instant
# and its refusal is the plainest. grep exits 1 when nothing matches, which is the good case.
set --
while IFS= read -r pattern || [ -n "$pattern" ]; do
  case $pattern in '#'*) continue ;; *[![:space:]]*) ;; *) continue ;; esac
  set -- "$@" -e "$pattern"
done < eval/conventions/forbidden-in-app.txt
if [ $# -gt 0 ]; then
  status=0
  found=$(grep -rEIn --exclude-dir=node_modules "$@" app) || status=$?
  if [ "$status" -eq 0 ]; then
    echo "[conventions] forbidden in app/:"
    printf '%s\n' "$found" | sed 's/^\([^:]*:[0-9]*\):/\1: /'
    exit 1
  elif [ "$status" -ne 1 ]; then
    echo "[conventions] the forbidden-names check could not run (grep exited $status)" >&2
    exit "$status"
  fi
fi
echo "[conventions] nothing in app/ names the acceptance tests' runner or reports"

# Secret scan: gitleaks at a pinned version (the image by digest), in its own container so nothing
# is installed on the grader. It reads the files, not git history, so the gate's copied tree is
# enough. app/ is mounted one level below the folder it scans, because gitleaks also reads a
# .gitleaks.toml and a .gitleaksignore from that folder; mounted this way, with --config naming the
# acceptance tests' own file, a builder's allowlist under app/ changes nothing. --redact keeps a
# found secret out of the log.
echo "[conventions] secret scan"
docker run --rm -v "$ROOT/app:/tree/app:ro" -v "$ROOT/eval/conventions/gitleaks.toml:/eval/gitleaks.toml:ro" \
  zricethezav/gitleaks:v8.30.1@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f \
  detect --no-git --source /tree --config /eval/gitleaks.toml --redact --no-banner

# Syntax of every JavaScript file. The sample application is one file; a real stack replaces this
# with its pinned formatter, linter and type checker, each configured from a file under
# eval/conventions/ and passed that file explicitly.
echo "[conventions] syntax"
find app -name '*.js' -type f | while read -r f; do node --check "$f"; done
echo "[conventions] clean"
