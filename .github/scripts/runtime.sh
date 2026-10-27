#!/usr/bin/env bash
# eval/runtime: what the acceptance tests need the gate's machine to have, one line each. This
# script turns the file into a workflow's outputs; the workflow installs only what the file names
# and chooses no language of its own.
#   runtime.sh <path to eval/runtime>      a missing file means the default machine with nothing installed
# Known lines:
#   runner <label>     the GitHub-hosted machine: ubuntu-latest (the default), macos-14, ...
#   node <version>     actions/setup-node
#   python <version>   actions/setup-python
#   java <version>     actions/setup-java, Temurin
#   android            KVM for the Android emulator on a Linux machine; the SDK is on GitHub's image
# A `#` starts a comment. Anything else the tests need is their own job: a container they start,
# or a step in eval/run.sh.
set -euo pipefail
FILE="${1:-eval/runtime}"
runner=ubuntu-latest; node=; python=; java=; android=
seen=
die() { echo "eval/runtime: $*" >&2; exit 1; }
once() { case " $seen " in *" $1 "*) die "line $n: '$1' is given twice";; esac; seen="$seen $1"; }
if [ -f "$FILE" ]; then
  n=0
  while IFS= read -r raw || [ -n "$raw" ]; do
    n=$((n + 1))
    line="${raw%%#*}"
    case "$line" in *[!A-Za-z0-9._[:space:]-]*) die "line $n: '$raw' has characters the gate does not accept (letters, digits, . _ - and spaces)";; esac
    set -- $line
    [ $# -eq 0 ] && continue
    key="$1"; value="${2:-}"
    [ $# -gt 2 ] && die "line $n: '$raw' has more than one value"
    case "$key" in
      runner|node|python|java)
        [ -n "$value" ] || die "line $n: '$key' needs a value, as in 'node 22' or 'runner macos-14'"
        once "$key"
        case "$key" in runner) runner="$value";; node) node="$value";; python) python="$value";; java) java="$value";; esac;;
      android)
        [ -z "$value" ] || die "line $n: 'android' takes no value"
        once android; android=1;;
      *) die "line $n: '$key' is not a line the gate knows (runner, node, python, java, android); anything else is the acceptance tests' own job, in a container or in eval/run.sh";;
    esac
  done < "$FILE"
fi
printf 'runner=%s\nnode=%s\npython=%s\njava=%s\nandroid=%s\n' "$runner" "$node" "$python" "$java" "$android"
