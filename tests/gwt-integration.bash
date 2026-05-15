#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)
tmp_dir=$(mktemp -d)

cleanup() {
    rm -rf "$tmp_dir"
}
trap cleanup EXIT

export GWT_CREATE_COMMAND="$repo_root/bin/gwt-create"
# shellcheck disable=SC1091
. "$repo_root/shell/gwt.sh"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_eq() {
    local expected=$1 actual=$2 message=$3
    if [ "$expected" != "$actual" ]; then
        printf 'FAIL: %s\nexpected: %s\nactual:   %s\n' "$message" "$expected" "$actual" >&2
        exit 1
    fi
}

resolve_dir() {
    cd "$1" >/dev/null 2>&1 && pwd -P
}

setup_repo() {
    local name=$1 repo
    repo="$tmp_dir/$name/main"
    mkdir -p "$repo"
    git -C "$repo" init -q
    git -C "$repo" config user.email "gwt-test@example.com"
    git -C "$repo" config user.name "gwt Test"
    printf 'initial\n' >"$repo/file.txt"
    git -C "$repo" add file.txt
    git -C "$repo" commit -qm "initial"
    resolve_dir "$repo"
}

assert_worktree_list_contains() {
    local repo=$1 worktree=$2
    git -C "$repo" worktree list --porcelain | grep -Fx "worktree $worktree" >/dev/null ||
        fail "expected worktree list to contain $worktree"
}

assert_worktree_list_missing() {
    local repo=$1 worktree=$2
    if git -C "$repo" worktree list --porcelain | grep -Fx "worktree $worktree" >/dev/null; then
        fail "expected worktree list not to contain $worktree"
    fi
}

test_create_from_main() {
    local repo created
    repo=$(setup_repo create-from-main)

    cd "$repo"
    gwt >/dev/null
    created=$(pwd -P)

    [ "$created" != "$repo" ] || fail "plain gwt from main should create a linked worktree"
    assert_worktree_list_contains "$repo" "$created"
    if git -C "$created" symbolic-ref -q HEAD >/dev/null; then
        fail "created worktree should be detached"
    fi
}

test_return_from_linked() {
    local repo worktree
    repo=$(setup_repo return-from-linked)
    worktree="$tmp_dir/return-from-linked/worktree"

    cd "$repo"
    gwt --path "$worktree" >/dev/null
    assert_eq "$worktree" "$(pwd -P)" "gwt --path should enter the linked worktree"

    gwt >/dev/null
    assert_eq "$repo" "$(pwd -P)" "plain gwt from a linked worktree should return to main"
    assert_worktree_list_contains "$repo" "$worktree"
}

test_remove_from_linked() {
    local repo worktree
    repo=$(setup_repo remove-from-linked)
    worktree="$tmp_dir/remove-from-linked/worktree"

    cd "$repo"
    gwt --path "$worktree" >/dev/null
    gwt --remove >/dev/null

    assert_eq "$repo" "$(pwd -P)" "gwt --remove should return to main"
    [ ! -e "$worktree" ] || fail "gwt --remove should delete the linked worktree directory"
    assert_worktree_list_missing "$repo" "$worktree"
}

test_dirty_remove_fails_in_place() {
    local repo worktree
    repo=$(setup_repo dirty-remove)
    worktree="$tmp_dir/dirty-remove/worktree"

    cd "$repo"
    gwt --path "$worktree" >/dev/null
    printf 'untracked\n' >"$worktree/untracked.txt"

    if gwt --remove >/dev/null 2>"$tmp_dir/dirty-remove.err"; then
        fail "gwt --remove should fail for dirty linked worktrees"
    fi

    assert_eq "$worktree" "$(pwd -P)" "failed gwt --remove should stay in the linked worktree"
    [ -e "$worktree/untracked.txt" ] || fail "failed gwt --remove should leave untracked files intact"

    cd "$repo"
    git -C "$repo" worktree remove --force "$worktree"
}

test_creation_args_still_create_from_linked() {
    local repo first second third
    repo=$(setup_repo creation-args)
    first="$tmp_dir/creation-args/first"
    second="$tmp_dir/creation-args/second"
    third="$tmp_dir/creation-args/third"

    cd "$repo"
    gwt --path "$first" >/dev/null
    gwt --path "$second" >/dev/null
    assert_eq "$second" "$(pwd -P)" "--path from linked worktree should create a new worktree"

    gwt HEAD --path "$third" >/dev/null

    assert_eq "$third" "$(pwd -P)" "commit-ish and --path from linked worktree should create a new worktree"
    assert_worktree_list_contains "$repo" "$first"
    assert_worktree_list_contains "$repo" "$second"
    assert_worktree_list_contains "$repo" "$third"
}

test_remove_from_main_fails() {
    local repo
    repo=$(setup_repo remove-from-main)

    cd "$repo"
    if gwt --remove >/dev/null 2>"$tmp_dir/remove-main.err"; then
        fail "gwt --remove should fail from the main worktree"
    fi
    assert_eq "$repo" "$(pwd -P)" "failed gwt --remove from main should stay in main"
}

test_stale_worktree_entries_are_tolerated() {
    local repo stale valid remove_target
    repo=$(setup_repo stale-worktrees)
    stale="$tmp_dir/stale-worktrees/stale"
    valid="$tmp_dir/stale-worktrees/valid"
    remove_target="$tmp_dir/stale-worktrees/remove-target"

    cd "$repo"
    git -C "$repo" worktree add --detach "$stale" HEAD >/dev/null 2>&1
    gwt --path "$valid" >/dev/null
    rm -rf "$stale"

    gwt >/dev/null
    assert_eq "$repo" "$(pwd -P)" "plain gwt should tolerate stale linked worktree entries"

    gwt --path "$remove_target" >/dev/null
    gwt --remove >/dev/null

    assert_eq "$repo" "$(pwd -P)" "gwt --remove should tolerate stale linked worktree entries"
    [ ! -e "$remove_target" ] || fail "gwt --remove should delete the current linked worktree with stale entries present"
    assert_worktree_list_missing "$repo" "$remove_target"
}

test_create_from_main
test_return_from_linked
test_remove_from_linked
test_dirty_remove_fails_in_place
test_creation_args_still_create_from_linked
test_remove_from_main_fails
test_stale_worktree_entries_are_tolerated

printf 'gwt integration tests passed\n'
