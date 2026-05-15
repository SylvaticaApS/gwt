# Plan: Return To Main Worktree

## Summary

Add return mode to `gwt` when invoked from a linked Git worktree. Plain `gwt`
returns to the main worktree root. `gwt --remove` safely removes the current
linked worktree and returns to the main worktree only after removal succeeds.

## Implementation

- Use `git worktree list --porcelain -z` in `shell/gwt.sh` to identify the main
  worktree and compare it with `git rev-parse --show-toplevel`.
- Treat only no-argument `gwt` and `gwt --remove` as return-mode commands inside
  linked worktrees.
- Preserve existing creation behavior for `gwt <commit-ish>`, `gwt --path`, and
  `gwt <commit-ish> --path`.
- Run `git -C <main-worktree> worktree remove <current-linked-worktree>` without
  `--force` for `gwt --remove`.
- Return to the main worktree root, not a mirrored relative subdirectory.
- Update help text, README usage, Bash completion, and glossary terminology.

## Verification

- Add a Bash integration test that creates temporary Git repositories and
  exercises create, return, remove, dirty-safe failure, dispatch, and main
  worktree remove refusal.
- Run syntax checks for Bash and Python.
