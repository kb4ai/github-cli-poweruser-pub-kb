# GitHub Projects - Basic CLI Usage

## ⚠️ CRITICAL: Authentication Setup First

**Before using any of these commands, ensure you have a CLASSIC personal access token:**

```bash
# REQUIRED: Use classic token (fine-grained tokens don't work)
source ${GITHUB_TOKEN_DOTFILE}
export GH_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN"

# Test authentication works
gh project list --owner @me
```

**If you see empty responses or null values, you're likely using a fine-grained token instead of a classic token.**

**Token Requirements:**

- ✅ **Classic Personal Access Token** with `project` scope
- ❌ **Fine-grained Personal Access Token** (causes empty API responses)
- ❌ **GitHub CLI auth** (may not set project scopes correctly)

**Create classic token at:** https://github.com/settings/tokens (use "Tokens (classic)")

## Project Discovery

```bash
# List your projects
gh project list

# List org projects
gh project list --owner myorg

# Get project details
gh project view 1 --owner "@me"

# Get project ID for automation
gh project view 1 --owner "@me" --format json | jq '.id'
```

## Adding Issues to Projects

```bash
# Add existing issue by URL
gh project item-add 1 --owner "@me" --url https://github.com/owner/repo/issues/23

# Add PR to project
gh project item-add 1 --owner "@me" --url https://github.com/owner/repo/pull/45

# Create draft item directly in project
gh project item-create 1 --owner "@me" --title "New Task" --body "Description"

# Create issue and assign to project (single command)
gh issue create --title "Bug Report" --body "Description" --project "My Project"
```

## Listing Project Items

```bash
# List all items in project
gh project item-list 1 --owner "@me"

# Get items as JSON for processing
gh project item-list 1 --owner "@me" --format json

# Find specific item by issue URL
gh project item-list 1 --owner "@me" --format json | jq '.items[] | select(.content.url=="https://github.com/owner/repo/issues/23")'

# Get item IDs for further operations
gh project item-list 1 --owner "@me" --format json | jq '.items[] | {id, title: .content.title}'
```

## Essential Workflow

```bash
# 1. Find your project
PROJECT_NUM=$(gh project list --format json | jq -r '.projects[0].number')

# 2. Create issue with project assignment
ISSUE_URL=$(gh issue create --title "New Feature" --body "Description" --json url --jq .url)

# 3. Add to project
gh project item-add $PROJECT_NUM --owner "@me" --url $ISSUE_URL

# 4. Get item ID for field updates
ITEM_ID=$(gh project item-list $PROJECT_NUM --owner "@me" --format json | jq -r --arg url "$ISSUE_URL" '.items[] | select(.content.url==$url) | .id')

echo "Issue created and added to project with item ID: $ITEM_ID"
```

## Common Use Cases

### Bulk Issue Addition
```bash
#!/bin/bash
# Authentication: Use classic token (required for Projects v2 API)
source ${GITHUB_TOKEN_DOTFILE}
export GH_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN"

PROJECT_NUM="1"
REPO="owner/repo"

# Add multiple issues to project
gh issue list --repo $REPO --json url,title | jq -r '.[] | .url' | while read url; do
    gh project item-add $PROJECT_NUM --owner "@me" --url "$url"
    echo "Added: $url"
done
```

### Project Dashboard
```bash
#!/bin/bash
# Quick project status overview
gh project view 1 --owner "@me" --format json | jq -r '
    "Project: \(.title)",
    "Items: \(.items | length)",
    "Open: \(.items | map(select(.content.state == "OPEN")) | length)",
    "Closed: \(.items | map(select(.content.state == "CLOSED")) | length)"
'
```