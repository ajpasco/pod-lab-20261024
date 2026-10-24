#!/bin/sh
# The eval. Always run from main's copy; never from the pull request's.
set -e
cd "$(dirname "$0")/.."
node --test eval/
