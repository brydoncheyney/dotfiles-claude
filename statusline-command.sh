#!/usr/bin/env bash

input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')

# time
time_str=$(date +%H:%M:%S)

# kubectl context
ctx=$(kubectl config current-context 2>/dev/null)
if [ $? -ne 0 ]; then
  ctx="none"
fi

# git branch (skip optional locks)
branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)

# build the status line: #### | time | ctx | dir [ | branch]
sep=" | "
parts="####${sep}${time_str}${sep}${ctx}${sep}${cwd}"
if [ -n "$branch" ]; then
  parts="${parts}${sep}${branch}"
fi

printf "%s" "$parts"
