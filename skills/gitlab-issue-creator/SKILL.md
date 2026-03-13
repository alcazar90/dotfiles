---
name: gitlab-issue-creator
description: Create GitLab issues from a JSON array of issue objects by calling the GitLab API. Use this skill whenever the user wants to push issues to GitLab, after running md-to-issues or when the user has a JSON array of issue objects ready to be created. Trigger on phrases like "create the issues", "push to GitLab", "send to GitLab", "create these in GitLab", or any request to actually create issues in a GitLab project.
---

# gitlab-issue-creator

Takes a JSON array of issue objects and creates them in a GitLab project via the API.

## Prerequisites

The user needs:
1. **jq** — JSON processor for bash (check with `command -v jq`)
2. **GitLab personal access token** — Scopes required: `api` (or at minimum `write_repository`)
3. **Project ID or namespace/project path** — e.g., `42` or `mygroup/myproject`
4. **GitLab host** — defaults to `https://gitlab.com`, can be self-hosted

If any of these are missing, ask for them before proceeding.

### Configuration Options

Credentials can be provided via:
- **Environment variables**: `GITLAB_TOKEN` and `GITLAB_PROJECT_ID`
- **.env file** in the working directory with these variables
- **Direct input** when prompted

The script will check for a `.env` file first and load credentials from there.

---

## Input Format

Expects a JSON array from `md-to-issues` or equivalent:

```json
[
  {
    "title": "Add JWT middleware to Express app",
    "description": "## Context\n...\n\n## Tasks\n\n* [ ] ...\n\n## Success Criteria\n\n...",
    "labels": ["feature", "backend"]
  }
]
```

---

## Implementation

Use bash + jq + curl. Write and execute a script to create all issues.

### Script Structure

The script should:
1. **Check dependencies** (jq availability)
2. **Load credentials** from .env if present
3. **Validate required variables** (TOKEN, PROJECT_ID)
4. **Iterate through issues** using jq
5. **Create each issue** via GitLab API
6. **Report results** with summary

### Script Template

```bash
#!/bin/bash

# Check for jq dependency
if ! command -v jq &> /dev/null; then
    echo "❌ Error: jq is required but not installed."
    echo "Install with: brew install jq (macOS) or apt-get install jq (Linux)"
    exit 1
fi

# Load credentials from .env if it exists
if [ -f .env ]; then
    source .env
fi

# Validate required environment variables
if [ -z "$GITLAB_TOKEN" ]; then
    echo "❌ Error: GITLAB_TOKEN is not set"
    echo "Please set it in .env file or export GITLAB_TOKEN=your_token"
    exit 1
fi

if [ -z "$GITLAB_PROJECT_ID" ]; then
    echo "❌ Error: GITLAB_PROJECT_ID is not set"
    echo "Please set it in .env file or export GITLAB_PROJECT_ID=your_project_id"
    exit 1
fi

# Configuration
GITLAB_HOST="${GITLAB_HOST:-https://gitlab.com}"
PROJECT_ID="$GITLAB_PROJECT_ID"
TOKEN="$GITLAB_TOKEN"

ISSUES_JSON='<JSON_ARRAY>'

# Process issues
total=$(echo "$ISSUES_JSON" | jq 'length')
created=0
failed=0

echo "Creating $total issues in GitLab project $PROJECT_ID..."
echo ""

# Use process substitution to avoid subshell and maintain counter variables
while IFS= read -r issue; do
    title=$(echo "$issue" | jq -r '.title')
    description=$(echo "$issue" | jq -r '.description')
    labels=$(echo "$issue" | jq -r '.labels | join(",")')

    # Build JSON payload with proper escaping using jq
    payload=$(jq -n \
        --arg t "$title" \
        --arg d "$description" \
        --arg l "$labels" \
        '{title: $t, description: $d, labels: $l}')

    # Make API request
    response=$(curl -s -w "\n%{http_code}" \
        --request POST \
        --header "PRIVATE-TOKEN: $TOKEN" \
        --header "Content-Type: application/json" \
        --data "$payload" \
        "$GITLAB_HOST/api/v4/projects/$PROJECT_ID/issues")

    # Extract status code and response body
    status=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    # Handle response
    if [ "$status" = "201" ]; then
        url=$(echo "$body" | jq -r '.web_url')
        echo "✅ Created: $title → $url"
        ((created++))
    else
        error_msg=$(echo "$body" | jq -r '.message // .error // "Unknown error"')
        echo "❌ Failed (HTTP $status): $title"
        echo "   Error: $error_msg"
        ((failed++))
    fi

    # Be polite to the API
    sleep 0.3
done < <(echo "$ISSUES_JSON" | jq -c '.[]')

echo ""
echo "--- Summary ---"
echo "Created: $created/$total"
[ $failed -gt 0 ] && echo "Failed: $failed"
```

---

## Security

**Never log or echo the token.** When constructing the script:
- The script loads credentials from `.env` file if present (recommended for local development)
- Alternatively, credentials can be set as environment variables
- **Never** hardcode tokens directly in the script file
- The token should only be referenced as `$GITLAB_TOKEN`

**Credential priority:**
1. Check for `.env` file and load with `source .env`
2. Fall back to existing environment variables
3. Exit with error if not found

**Example .env file:**
```bash
GITLAB_TOKEN=glpat-xxxxxxxxxxxxx
GITLAB_PROJECT_ID=12345
GITLAB_HOST=https://gitlab.com  # optional, defaults to gitlab.com
```

The script validates that required variables are set before proceeding.

---

## Execution Flow

1. **Check for .env file** — if present, use credentials from there; otherwise ask for configuration
2. **Verify jq is installed** — fail early with installation instructions if missing
3. **Show preview** — list how many issues will be created and their titles
4. **Get confirmation** from user before proceeding
5. **Write the script** to a file (e.g., `create_issues.sh`)
6. **Execute the script** — it will validate credentials and create issues
7. **Report results** — show created issue URLs and any failures with detailed error messages

The script handles all validation internally and will exit with clear error messages if:
- jq is not installed
- .env file exists but required variables are missing
- API requests fail (with HTTP status codes and error messages)

---

## Error Handling

| HTTP Code | Meaning | Action |
|---|---|---|
| 201 | Created | Log URL |
| 401 | Bad token | Stop, ask user to verify token and scopes |
| 403 | Forbidden | Stop, check project permissions |
| 404 | Project not found | Stop, verify project ID/path |
| 429 | Rate limited | Retry with backoff |
| 422 | Validation error | Log issue title + error, continue with rest |

---

## After Creation

The script outputs progress in real-time and provides a final summary:

```
Creating 14 issues in GitLab project 77122591...

✅ Created: Create User model and database migration → https://gitlab.com/mygroup/myproject/-/issues/42
✅ Created: Implement password hashing utility → https://gitlab.com/mygroup/myproject/-/issues/43
❌ Failed (HTTP 422): Invalid issue title
   Error: Title is too short (minimum is 1 character)
...

--- Summary ---
Created: 13/14
Failed: 1
```

## Why This Approach?

**Advantages of bash + jq over bash + Python:**
- ✅ **Simpler** — Pure bash with standard Unix tools
- ✅ **Faster** — No Python subprocess overhead
- ✅ **More readable** — Easier to debug and modify
- ✅ **Better error handling** — jq handles JSON escaping automatically
- ✅ **Dependency checking** — Validates jq and credentials before running
- ✅ **Secure** — Loads credentials from .env, never hardcoded

**Dependencies:**
- `jq` — Available via package managers on all platforms
- `curl` — Usually pre-installed on Unix systems

**Technical Notes:**
- Uses process substitution `< <(...)` instead of pipe to avoid subshell issues and maintain accurate counters
- Uses `sed '$d'` instead of `head -n-1` for macOS compatibility (BSD vs GNU head)
- Validates credentials before making any API calls to fail fast
