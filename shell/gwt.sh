#!/usr/bin/env bash

__gwt_script_path() {
    readlink -f "${BASH_SOURCE[0]}"
}

__gwt_repo_root() {
    local script_path script_dir
    script_path="$(__gwt_script_path)"
    script_dir=$(dirname "$script_path")
    cd "$script_dir/.." >/dev/null 2>&1 && pwd
}

__gwt_create_command() {
    printf '%s\n' "${GWT_CREATE_COMMAND:-$(__gwt_repo_root)/bin/gwt-create}"
}

__gwt_usage() {
    cat <<'EOF'
Usage:
  gwt
  gwt --remove
  gwt <commit-ish>
  gwt --path <path>
  gwt <commit-ish> --path <path>

Creates a detached git worktree from HEAD by default, or from the supplied commit-ish,
then changes the current shell directory into the new worktree.

When run without creation arguments from a linked worktree, changes back to the
main worktree. With --remove, safely removes the current linked worktree before
changing back to the main worktree.
EOF
}

__gwt_resolve_dir() {
    cd "$1" >/dev/null 2>&1 && pwd -P
}

__gwt_worktree_context() {
    __gwt_main_worktree=""
    __gwt_current_worktree=""
    __gwt_is_linked_worktree="false"

    local current entry record_path="" record_is_bare="false" record_count=0
    local record_resolved
    current=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
    current=$(__gwt_resolve_dir "$current") || return 1

    __gwt_finish_worktree_record() {
        if [ -z "$record_path" ]; then
            return 0
        fi

        record_count=$((record_count + 1))
        if [ "$record_is_bare" = "true" ]; then
            record_path=""
            record_is_bare="false"
            return 0
        fi

        if ! record_resolved=$(__gwt_resolve_dir "$record_path"); then
            if [ $record_count -eq 1 ]; then
                return 1
            fi
            record_path=""
            record_is_bare="false"
            return 0
        fi

        if [ $record_count -eq 1 ]; then
            __gwt_main_worktree=$record_resolved
        fi
        if [ "$record_resolved" = "$current" ]; then
            __gwt_current_worktree=$record_resolved
        fi

        record_path=""
        record_is_bare="false"
    }

    while IFS= read -r -d '' entry; do
        case "$entry" in
            "")
                __gwt_finish_worktree_record || return 1
                ;;
            worktree\ *)
                __gwt_finish_worktree_record || return 1
                record_path=${entry#worktree }
                ;;
            bare)
                record_is_bare="true"
                ;;
        esac
    done < <(git worktree list --porcelain -z 2>/dev/null)
    __gwt_finish_worktree_record || return 1
    unset -f __gwt_finish_worktree_record

    if [ -z "$__gwt_current_worktree" ]; then
        return 1
    fi

    if [ -n "$__gwt_main_worktree" ] && [ "$__gwt_current_worktree" != "$__gwt_main_worktree" ]; then
        __gwt_is_linked_worktree="true"
    fi
}

__gwt_return_to_main_worktree() {
    local remove_current=$1

    if ! __gwt_worktree_context; then
        if [ "$remove_current" = "true" ]; then
            printf 'gwt: not inside a git worktree\n' >&2
        fi
        return 1
    fi

    if [ -z "$__gwt_main_worktree" ]; then
        if [ "$remove_current" = "true" ]; then
            printf 'gwt: no main worktree to return to for this repository\n' >&2
        fi
        return 1
    fi

    if [ "$__gwt_is_linked_worktree" != "true" ]; then
        if [ "$remove_current" = "true" ]; then
            printf 'gwt: refusing to remove the main worktree: %s\n' "$__gwt_main_worktree" >&2
            return 1
        fi
        return 1
    fi

    if [ "$remove_current" = "true" ]; then
        if ! git -C "$__gwt_main_worktree" worktree remove "$__gwt_current_worktree"; then
            return 1
        fi
    fi

    builtin cd -- "$__gwt_main_worktree" || return 1
    if [ "$remove_current" = "true" ]; then
        printf 'gwt: removed %s and returned to %s\n' "$__gwt_current_worktree" "$__gwt_main_worktree"
    else
        printf 'gwt: returned to %s\n' "$__gwt_main_worktree"
    fi
}

__gwt_load_git_completion() {
    if declare -F __git_complete_refs >/dev/null 2>&1; then
        return 0
    fi

    if [ -r /usr/share/bash-completion/completions/git ]; then
        # shellcheck disable=SC1091
        . /usr/share/bash-completion/completions/git
    fi

    declare -F __git_complete_refs >/dev/null 2>&1
}

__gwt_complete_path() {
    local path_cur="${1:-$cur}"
    local prefix="${2:-}"
    local reply

    COMPREPLY=()
    while IFS= read -r reply; do
        COMPREPLY+=("${prefix}${reply}")
    done < <(compgen -f -- "$path_cur")

    if declare -F compopt >/dev/null 2>&1; then
        compopt -o filenames
    fi
}

__gwt_complete_refs() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        COMPREPLY=()
        return
    fi

    if __gwt_load_git_completion; then
        __git_complete_refs
        return
    fi

    COMPREPLY=($(compgen -W "$(git for-each-ref --format='%(refname:short)' refs/heads refs/tags refs/remotes 2>/dev/null) HEAD ORIG_HEAD FETCH_HEAD" -- "$cur"))
}

_gwt_complete() {
    local cur prev cword
    local i word positional_count=0 expect_path=0

    cur=${COMP_WORDS[COMP_CWORD]:-}
    prev=${COMP_WORDS[COMP_CWORD - 1]:-}
    cword=$COMP_CWORD

    if [ "$prev" = "--path" ]; then
        __gwt_complete_path
        return
    fi

    case "$cur" in
        --path=*)
            __gwt_complete_path "${cur#--path=}" "--path="
            return
            ;;
        -*)
            COMPREPLY=($(compgen -W "--path --remove --help -h" -- "$cur"))
            return
            ;;
    esac

    for ((i = 1; i < cword; i++)); do
        word=${COMP_WORDS[i]}
        if [ $expect_path -eq 1 ]; then
            expect_path=0
            continue
        fi

        case "$word" in
            --path)
                expect_path=1
                ;;
            --path=*)
                ;;
            -*)
                ;;
            *)
                positional_count=$((positional_count + 1))
                ;;
        esac
    done

    if [ $positional_count -eq 0 ]; then
        case "$cur" in
            /*|./*|../*|~/*)
                __gwt_complete_path
                ;;
            *)
                __gwt_complete_refs
                ;;
        esac
        return
    fi

    COMPREPLY=()
}

gwt() {
    local create_cmd base="" path="" output remove_current="false"
    local repo_root="" worktree_path="" base_ref="" commit_sha="" detached_head=""

    if [ $# -eq 1 ]; then
        case "$1" in
            /*|./*|../*|~/*)
                path=$1
                set --
                ;;
        esac
    fi

    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                __gwt_usage
                return 0
                ;;
            --path)
                if [ $# -lt 2 ]; then
                    printf 'gwt: --path requires a value\n' >&2
                    return 2
                fi
                path=$2
                shift 2
                continue
                ;;
            --path=*)
                path=${1#--path=}
                shift
                continue
                ;;
            --remove)
                remove_current="true"
                shift
                continue
                ;;
            -*)
                printf 'gwt: unsupported option: %s\n' "$1" >&2
                return 2
                ;;
            *)
                if [ -n "$base" ]; then
                    printf 'gwt: unexpected argument: %s\n' "$1" >&2
                    return 2
                fi
                base=$1
                shift
                continue
                ;;
        esac
    done

    if [ "$remove_current" = "true" ]; then
        if [ -n "$base" ] || [ -n "$path" ]; then
            printf 'gwt: --remove cannot be combined with creation arguments\n' >&2
            return 2
        fi
        __gwt_return_to_main_worktree true
        return $?
    fi

    if [ -z "$base" ] && [ -z "$path" ] && __gwt_return_to_main_worktree false; then
        return 0
    fi

    create_cmd="$(__gwt_create_command)"
    if [ ! -x "$create_cmd" ]; then
        printf 'gwt: missing executable: %s\n' "$create_cmd" >&2
        return 127
    fi

    local cmd=("$create_cmd")
    if [ -n "$base" ]; then
        cmd+=(--base "$base")
    fi
    if [ -n "$path" ]; then
        cmd+=(--path "$path")
    fi

    output="$("${cmd[@]}")"
    local status=$?
    if [ $status -ne 0 ]; then
        return $status
    fi

    eval "$output"

    if [ -z "$worktree_path" ]; then
        printf 'gwt: did not receive worktree path from %s\n' "$create_cmd" >&2
        return 1
    fi

    if [ "$detached_head" != "true" ]; then
        printf 'gwt: refusing to cd into a non-detached worktree: %s\n' "$worktree_path" >&2
        return 1
    fi

    builtin cd -- "$worktree_path" || return 1
    printf 'gwt: %s (%s at %s)\n' "$worktree_path" "$base_ref" "$commit_sha"
}

complete -o bashdefault -o default -F _gwt_complete gwt
