# Global Claude Instructions

## User

Brydon Cheyney — Senior DevOps Engineer at NerdWallet.

## PR Workflow

After opening a draft PR, immediately invoke the `pr-workflow` skill without waiting to be asked.

## Pull Requests

For PR descriptions, include a summary of what the changes do. Do NOT include a "Test plan" section with unchecked checkboxes for future testing — CI handles that. If any testing was actually performed (e.g. a `terraform plan` was run, a command was executed, something was manually verified), mention it briefly in prose.

## Commits

Never commit to master/main, always create a branch and open a github PR in draft mode.
Always try to add the appropriate jira issue key in the commit message, e.g.

```
[PRODENG-1394] Add support for new API endpoint
This adds the new API endpoint for fetching user data
```

The branch should be prefixed by the jira issue key as well, e.g. `PRODENG-1394-add-support-for-new-api-endpoint`.

## GitHub CLI

Prefer dedicated `gh` subcommands over `gh api` for read-only operations — the subcommands are already in the auto-approve allowlist while `gh api` is not. Common replacements:

| Instead of `gh api` | Use |
|---|---|
| `gh api repos/{o}/{r}/commits/{sha}/check-runs` | `gh pr checks {pr} --repo {o}/{r}` |
| `gh api repos/{o}/{r}/commits/{sha}/status` | `gh pr checks {pr} --repo {o}/{r} --json name,state,description` |
| `gh api repos/{o}/{r}/pulls/{n}` | `gh pr view {n} --repo {o}/{r}` |
| `gh api repos/{o}/{r}/pulls/{n}/comments` | `gh pr view {n} --repo {o}/{r} --comments` |
| `gh api repos/{o}/{r}/actions/runs` | `gh run list --repo {o}/{r}` |
| `gh api repos/{o}/{r}/actions/runs/{id}` | `gh run view {id} --repo {o}/{r}` |

Only fall back to `gh api` when no dedicated subcommand exists (e.g., fetching raw commit status descriptions for Terraform Cloud plan summaries).

## Git

Always specify the branch name explicitly when pushing:

```bash
git push origin my-branch-name   # correct
git push origin                  # wrong
```

## AWS CLI profile selection

Always use the `.read` profile for an account for all read-only operations (list, describe, get, etc.). Only switch to a privileged role (`.admin`, `.backup-administrator`, `.engineer`, etc.) for the specific command that requires write access, then switch back to `.read` immediately after.

### Profile placement

When a command uses a profile with "admin" or other privileged role in the name, put `--profile` at the **beginning** (right after `aws`). When using a `.read` profile, put `--profile` at the **end**. This ensures read-only commands match the auto-approve allowlist while privileged commands do not.

```bash
# privileged profile — at the beginning (will NOT auto-approve)
aws --profile nwbackup.backup-administrator backup start-report-job ...
# read profile — at the end (will auto-approve)
aws backup list-report-plans --profile nwbackup.read
```

## Terraform

### Provider version pins

Workspaces use `~> X.0`; modules use `>= X.0`:

```hcl
# workspace required_providers
version = "~> 6.0"
# module required_providers
version = ">= 6.0"
```

### Prefer for_each over duplicate resource blocks

Always reach for `for_each` rather than creating a second named resource. When adding `for_each` to an existing resource or module, always add `moved` blocks so Terraform renames state instead of destroying and recreating:

```hcl
moved {
  from = aws_backup_vault.historical_backups
  to   = aws_backup_vault.historical_backups["us-east-1"]
}
```

### Module argument ordering

Inside a module block: `source`, then `providers`/`region`, then `for_each`, then the rest. Put a blank line between each group:

```hcl
module "example" {
  source = "../../modules/foo"

  providers = {
    aws = aws.nwbackup
  }

  region = each.key

  for_each = toset(["us-east-1", "us-east-2"])

  key_alias = "..."
}
```

## Prefer evidence over estimates

When answering questions that can be grounded in real data, use authoritative sources — don't calculate or estimate when you can query. This applies broadly: costs, resource counts, usage metrics, API behavior, configuration state, etc.

- **AWS costs**: use Cost Explorer (`aws ce get-cost-and-usage`) as the source of truth, not calculations from resource describe calls. Components like PITR storage, GSI storage, and retained snapshots are easy to miss and can significantly change the numbers. Use tags to isolate costs by owner/project when available. DynamoDB total cost includes table storage, GSI storage, PITR storage, backup storage, and request units — `describe-table` alone doesn't surface PITR or GSI costs.
- **Infrastructure state**: query real APIs (CloudWatch, CloudQuery, describe calls) rather than inferring from config files.
- **API/CLI behavior**: if uncertain how something behaves, run the command and observe the output — don't theorize.

## Debugging & investigation

When asked to investigate, debug, or explain why something isn't working:

1. **Test first, theorize second.** Run the relevant command or reproduce the issue before reasoning about causes. Observed output is more reliable than inference.
2. **Show your work.** Include the exact command you ran and its output — don't summarize or paraphrase API responses when the raw output is what matters.
3. **Don't speculate when you can verify.** If you're uncertain whether a permission, config value, or behavior applies, test it directly rather than listing possibilities.
4. **Narrow scope before going broad.** Start with the specific thing that's failing, not the surrounding system. Only expand the investigation if the narrow path doesn't explain it.

## PR descriptions

When bumping any version (provider, module, dependency), link to the changelog. For major version bumps, summarize the relevant breaking changes.

When fixing a bug, include the exact error message in the PR description so it's searchable in git history. Focus on what was wrong and what we changed, not the implementation details.

## Parallel investigation across accounts or regions

When a task involves running the same investigation, check, or operation across multiple AWS accounts or regions, use parallel subagents rather than looping sequentially. Each subagent handles one account/region and reports back; compile results into a single summary. This applies to: compliance checks, cost queries, resource audits, backup status, deletion protection checks, etc.
