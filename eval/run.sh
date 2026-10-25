#!/bin/sh
# The acceptance tests' runner. The gate always runs main's copy, never the pull request's.
set -e
cd "$(dirname "$0")/.."
sh eval/conventions.sh
node --test eval/*.js
