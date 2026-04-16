#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)
bashrc="$HOME/.bashrc"
local_bin="$HOME/.local/bin"
local_share="$HOME/.local/share/gwt"
create_link="$local_bin/gwt-create"
shell_link="$local_share/gwt.sh"
source_line='if [ -f "$HOME/.local/share/gwt/gwt.sh" ]; then'
source_body='    . "$HOME/.local/share/gwt/gwt.sh"'
source_end='fi'

mkdir -p "$local_bin" "$local_share"
ln -sfn "$repo_root/bin/gwt-create" "$create_link"
ln -sfn "$repo_root/shell/gwt.sh" "$shell_link"

touch "$bashrc"

if ! grep -Fqx "$source_line" "$bashrc"; then
    {
        printf '\n'
        printf '%s\n' "$source_line"
        printf '%s\n' "$source_body"
        printf '%s\n' "$source_end"
    } >>"$bashrc"
fi

printf 'Installed gwt.\n'
printf '  gwt-create -> %s\n' "$create_link"
printf '  gwt.sh      -> %s\n' "$shell_link"
printf 'Reload bash with: exec bash -i\n'
