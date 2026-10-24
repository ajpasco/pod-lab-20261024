# pod lab, 2026-10-24

Disposable. Safe to delete. Proves the GitHub shape for pod in one afternoon:

1. the eval runs from main's copy against the pull request's `app/`, so a builder's edit to a test in its own branch changes nothing about its verdict;
2. a story pull request that stays inside `app/` merges on green with nobody clicking;
3. a pull request that touches `eval/`, `.github/` or `docs/` waits for the founder's approval, a commit status on that exact commit, and merges without a manual re-run once it lands;
4. `pod-approve.sh` from a terminal sets the same status the console button will.

Nothing here is a product. The names are placeholders.
