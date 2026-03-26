---
name: gha-plan-review
description: Extract the full resource-level breakdown from a GitHub Actions Terraform plan job log. Returns a formatted summary of what will be added, changed, or destroyed.
---

# GHA Plan Review

Fetch and parse the Terraform plan output from a GitHub Actions run, presenting a resource-level breakdown of changes.

## Usage

Invoked with a PR number and optionally a specific environment (e.g. `94 Production`). If no environment is specified, summarise all plan jobs.

## Steps

### 1. Find the plan job run IDs

```bash
gh pr checks {pr} --repo {owner}/{repo} --json name,state,description,link \
  | jq '.[] | select(.name | test("Plan"; "i"))'
```

Extract the run ID from the `link` field (e.g. `https://github.com/{owner}/{repo}/actions/runs/{run_id}/job/{job_id}`).

### 2. Get the plan log for each run

```bash
gh run view --repo {owner}/{repo} {run_id} --log 2>&1 \
  | grep "Terraform Plan\|PLAN_SUMMARY\| # \| + \| - \| ~ \|Plan:"
```

The plan output is embedded in the job log. Key patterns to extract:

- `# {resource} will be created` → add
- `# {resource} will be destroyed` → destroy
- `# {resource} will be updated in-place` → change
- `# {resource} must be replaced` → replace (destroy + create)
- `Plan: N to add, N to change, N to destroy.` → summary line
- `PLAN_SUMMARY:` → GitHub Actions summary line with emoji prefix

### 3. Present the breakdown

For each environment with changes, output a table:

```
**Production** — 3 to add, 0 to change, 0 to destroy
| Action  | Resource |
| ------- | -------- |
| add     | module.db_user.aws_secretsmanager_secret.password |
| add     | module.db_user.postgresql_role.this |
| add     | module.db_user.postgresql_grant.database |
```

If a plan has no changes (`0 to add, 0 to change, 0 to destroy`), say so in one line — no table needed.

If the log is truncated or the plan output is not found, fall back to the `description` field from `gh pr checks` which contains the summary line.
