# Research: Return To Main Worktree

## Current Behavior

- `shell/gwt.sh` defines the user-facing `gwt` Bash function because a sourced
  function can change the caller's current directory.
- `bin/gwt-create` creates detached Git worktrees and emits shell-safe variable
  assignments consumed by the Bash function.
- Plain `gwt` currently creates a detached worktree from `HEAD`.
- `--path` chooses the new worktree path, and one path-like positional argument
  is treated as a path shortcut.

## Git Worktree Behavior

- `git worktree list --porcelain -z` provides machine-readable worktree data.
- Git lists the main worktree first, followed by linked worktrees.
- `git worktree remove <path>` removes a linked worktree and its administrative
  files.
- Without `--force`, Git refuses to remove dirty, untracked, or locked
  worktrees, and the main worktree cannot be removed.

## Design Findings

- Return behavior belongs in `shell/gwt.sh`, not `bin/gwt-create`, because it
  changes the caller's directory and may remove the current working directory.
- "Base branch" should be documented as "main worktree" for this feature because
  no branch switching is involved.
- The feature should apply to any linked worktree for the repository, including
  worktrees not created by `gwt`.
