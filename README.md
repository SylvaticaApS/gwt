# gwt

`gwt` is a small bash helper for creating detached Git worktrees quickly.

It:

- only works inside a Git repository;
- creates a detached worktree from the current `HEAD` by default;
- accepts an explicit commit-ish override;
- creates the worktree under `$REPO_ROOT/../worktrees/<random-id>` by default;
- accepts an explicit `--path` override;
- changes the current shell directory into the new worktree;
- provides bash completion for refs and `--path`.

## Repository Layout

- [bin/gwt-create](./bin/gwt-create): executable that creates the detached worktree and prints shell-safe output.
- [shell/gwt.sh](./shell/gwt.sh): bash function and completion definition for `gwt`.
- [install.sh](./install.sh): installs symlinks into `~/.local` and adds the `.bashrc` source hook if needed.

## Install

Run:

```bash
chmod +x ./install.sh ./bin/gwt-create
./install.sh
exec bash -i
```

The installer:

- symlinks `~/.local/bin/gwt-create` to this repo;
- symlinks `~/.local/share/gwt/gwt.sh` to this repo;
- ensures `~/.bashrc` sources `~/.local/share/gwt/gwt.sh`.

If you do not want to use `install.sh`, add this to `~/.bashrc` yourself:

```bash
if [ -f "$HOME/.local/share/gwt/gwt.sh" ]; then
    . "$HOME/.local/share/gwt/gwt.sh"
fi
```

Then create the symlinks manually:

```bash
mkdir -p ~/.local/bin ~/.local/share/gwt
ln -sfn "$PWD/bin/gwt-create" ~/.local/bin/gwt-create
ln -sfn "$PWD/shell/gwt.sh" ~/.local/share/gwt/gwt.sh
exec bash -i
```

## Usage

```bash
gwt
gwt HEAD~1
gwt --path ../worktrees/manual-test
gwt main --path /tmp/my-worktree
```

## Notes

- `gwt` must be loaded as a bash function to change the current shell directory.
- A plain executable cannot `cd` the parent shell, which is why the shell integration lives in [shell/gwt.sh](./shell/gwt.sh).
- If you update this repo, the installed command uses the updated files automatically because the home-directory install is symlink-based.
- The default `gwt` flow expects the current repository to have at least one commit so `HEAD` resolves.
