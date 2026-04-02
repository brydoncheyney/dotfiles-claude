---
name: nerdoracle
description: Search NerdWallet's indexed codebase to answer cross-system questions, find implementations, locate configuration, and understand how services connect. Use proactively when working on anything that touches multiple repositories or services.
license: MIT
compatibility: opencode
metadata:
  audience: nerdwallet-engineers
  system: nerdoracle
---

## Staying up to date

Before using any NerdOracle tools, check whether the local installation is up to date. Run this once — if the result is already cached from today, skip it:

```bash
cd ~/.local/share/nerdoracle && git fetch --quiet origin main 2>/dev/null && \
  LOCAL=$(git rev-parse HEAD) && REMOTE=$(git rev-parse origin/main) && \
  if [ "$LOCAL" != "$REMOTE" ]; then \
    git pull --quiet origin main && npm install --silent && \
    echo "NerdOracle updated. Skill may have changed — please reload."; \
  else \
    echo "NerdOracle is up to date."; \
  fi
```

If the output says "NerdOracle updated", let the user know and suggest they reload their MCP client to pick up any changes.

If the directory doesn't exist, NerdOracle is not installed — direct the user to follow the install instructions in the README at `https://github.com/nerdwallet/nerdoracle`.

---

## What I do

I give you access to NerdOracle — a semantic search index over NerdWallet's GitHub repositories. I help you answer questions that span multiple codebases without manually hunting through repos.

## When to use me

Use me proactively whenever:

- You're working on a feature that touches more than one service and need to understand how they connect
- You need to find where something is implemented (an event handler, an API endpoint, a data model, a calculation) and aren't sure which repo owns it
- You want to understand how other services have solved a similar problem (rate limiting, auth, retries, etc.)
- You need to find all callers of an API, all consumers of an event, or all places a pattern is used
- You're onboarding to a service and want to understand its structure quickly
- You're asked to make a change and need to assess blast radius across the codebase

**Do not wait to be asked.** If the user's question involves cross-service concerns or unfamiliar code, search NerdOracle first before asking the user to provide context manually.

## How to use me

### Searching code

Use `search_code` with a natural language query. Be specific about what you're looking for:

```
search_code(query="JWT token validation middleware")
search_code(query="event handler for order.completed", language="go")
search_code(query="credit card reward rate calculation", repository="nerdwallet/marketplace-eks")
search_code(query="rate limiting implementation", file_path="src/middleware")
```

Results include the matching code, the file location, similarity score, and the module summary (imports, exported symbols) for context.

### Checking what's indexed

Before searching, you may want to verify the relevant repository is indexed:

```
list_repositories()
get_ingestion_status(repository="nerdwallet/some-repo")
```

### Adding a missing repository

If a repository is not yet indexed, **always ask the user for confirmation before registering or triggering ingestion.** Indexing takes 2-10 minutes for a typical repository and consumes AWS Bedrock API resources.

Say something like:

> "I don't have `nerdwallet/some-repo` indexed yet. Would you like me to add it? Indexing will take a few minutes."

If the user confirms, then:

```
register_repository(owner="nerdwallet", name="repo-name")
trigger_ingestion(repository="nerdwallet/repo-name")
```

Let the user know ingestion is running and that you can check progress with `get_ingestion_status`. You don't need to poll for completion — continue the conversation and check status if the user asks.

Only repositories from the `nerdwallet` GitHub organisation can be indexed.

### Understanding a specific file

If `search_code` returns a result and you want to understand the file's full structure:

```
get_file(repository="nerdwallet/marketplace-eks", file_path="src/marketplace/lib/calculations/credit_cards.py")
```

## Limitations

- Only repositories that have been ingested are searchable. If a repo was recently created or has never been indexed, register and trigger ingestion.
- The index reflects the state of the default branch at the time of the last ingestion run. Very recent changes may not be reflected.
- Search quality is best for specific, concrete queries. Broad architectural questions ("how does the whole payments system work") are better answered by combining several targeted searches.
- Very large files are truncated at indexing time — extremely long generated files or vendored code may have reduced search quality.

## Example workflows

**Cross-service feature design:**

> "I need to add a new field to the user profile. Where is the user profile defined and who reads it?"
> → `search_code(query="user profile schema definition")`
> → `search_code(query="user profile consumer read access")`

**Finding a pattern across services:**

> "How do other services implement circuit breakers?"
> → `search_code(query="circuit breaker implementation retry")`

**Locating an event handler:**

> "What handles the payment.failed event?"
> → `search_code(query="payment.failed event handler consumer")`

**Assessing blast radius:**

> "I'm changing the rewards calculation API. Who calls it?"
> → `search_code(query="rewards calculation API client caller")`
