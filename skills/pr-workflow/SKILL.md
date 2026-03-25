---
name: pr-workflow
description: After a draft PR is opened, poll checks, collect change summary, mark PR ready, and post Slack review request. Runs automatically after any new draft PR is created.
---

# PR Workflow

After a draft PR is opened, automatically run this workflow — no explicit invocation needed.

## Trigger

Run this automatically whenever a new GitHub PR has just been created in draft mode. Do not wait to be asked.

## Steps

### 1. Poll until all checks pass

```bash
gh pr checks {pr} --repo {owner}/{repo} --json name,state,description,link
```

Poll every ~30 seconds. Wait until all checks have `state == "SUCCESS"`. If a check fails, handle it per the rules below before stopping.

#### Semgrep failures

If `semgrep-cloud-platform/scan` fails, triage it before giving up:

1. **Read the finding** from the PR's inline review comments:
   ```bash
   gh api repos/{owner}/{repo}/pulls/{pr}/comments | jq '.[0]'
   ```
   Semgrep posts a blocking comment with the rule name and suggested fix.

2. **Present the finding to the user** and ask how to handle it. Options:
   - Fix the actual issue in the code
   - `/ar <reason>` — acceptable risk
   - `/fp <reason>` — false positive
   - `/other <reason>` — any other reason

   Once the user decides, reply to the comment thread:
   ```bash
   gh api repos/{owner}/{repo}/pulls/{pr}/comments/{comment_id}/replies \
     -X POST -f body="/{command} <reason>"
   ```

3. **Wait for Semgrep to acknowledge** — poll the thread until a reply appears with `"Status updated to \`ignored"`:
   ```bash
   gh api repos/{owner}/{repo}/pulls/{pr}/comments \
     | jq '[.[] | select(.in_reply_to_id == {comment_id})] | last | .body'
   ```

4. **Resolve the review thread** via GraphQL:
   ```bash
   # Get the thread node ID
   gh api graphql -f query='{ repository(owner:"{owner}", name:"{repo}") {
     pullRequest(number:{pr}) { reviewThreads(first:10) { nodes {
       id isResolved comments(first:1) { nodes { databaseId } }
     } } } } }' \
     | jq '.data.repository.pullRequest.reviewThreads.nodes[]
           | select(.comments.nodes[0].databaseId == {comment_id}) | .id'

   # Resolve it
   gh api graphql -f query='mutation {
     resolveReviewThread(input: {threadId: "{thread_node_id}"}) {
       thread { isResolved }
     }
   }'
   ```

5. **Trigger a re-scan** — the Semgrep check suite is owned by the Semgrep GitHub App, so the `rerequest` API returns 404. Instead, find the check run ID and give the user a direct link to click "Re-run failed checks":
   ```bash
   sha=$(gh pr view {pr} --repo {owner}/{repo} --json headRefOid -q '.headRefOid')
   gh api repos/{owner}/{repo}/commits/$sha/check-runs \
     | jq '.check_runs[] | select(.app.slug | test("semgrep"; "i")) | .id'
   ```
   Then present: `https://github.com/{owner}/{repo}/pull/{pr}/checks?check_run_id={id}`

6. **Poll until the re-scan completes**:
   ```bash
   gh api repos/{owner}/{repo}/commits/$sha/check-runs \
     | jq '.check_runs[] | select(.app.slug | test("semgrep"; "i")) | "\(.status) \(.conclusion)"'
   ```
   Once `completed success`, continue with the rest of the workflow.

### 2. Collect change summary

From the same `gh pr checks` output:

- **Terraform Cloud checks**: `description` field contains the plan summary (e.g. `"Terraform plan: 0 to add, 1 to change, 0 to destroy."`), `link` points to the TFC run.
- **GitHub Actions plan jobs**: invoke the `gha-plan-review` skill to get the full resource-level breakdown.

Present a table of checks that have actual changes, with links. If everything is no-changes, say so briefly.

### 3. Mark PR ready and post Slack message

Immediately after presenting the change summary — no confirmation needed, the tool approval prompt is the gate:

```bash
gh pr ready {pr} --repo {owner}/{repo}
```

#Then post a Slack message asking for review. Use the voice subagent (spawn a general-purpose Agent that reads `~/.claude/voice.md`) to write the message. Keep it one sentence, casual, in Brydon's voice.
#
#**Where to post:**
#- Prod Eng only → `#prodeng-priv`
#- Infrastructure Eng + Prod Eng, or Infrastructure Eng only → `#infrastructure-org` (`G01G8EGR2ES`)
#- If unsure, ask before posting.
#
#Use `mcp__slack__slack_post_message` (prefer `mcp__slack__` over `mcp__plugin_slack_slack__`).
