# GitHub PR Review Comments API Guide

## Overview

This comprehensive guide covers how to programmatically read GitHub Pull Request inline code review comments using GitHub CLI and API. GitHub provides two distinct types of comments for pull requests:

1. **Pull Request Review Comments**: Comments on specific lines of code in the diff (inline comments)
2. **Issue Comments**: General comments on the pull request (not tied to specific lines)

This guide focuses primarily on **Pull Request Review Comments** which are the inline code review comments that developers add to specific lines in the diff.

## API Endpoints

### REST API Endpoints

GitHub provides several REST API endpoints for accessing PR review comments:

#### Primary Endpoints (Read Operations)

- **List review comments for a PR**: `GET /repos/{owner}/{repo}/pulls/{pull_number}/comments`
- **List reviews for a PR**: `GET /repos/{owner}/{repo}/pulls/{pull_number}/reviews`  
- **List general PR comments**: `GET /repos/{owner}/{repo}/issues/{issue_number}/comments`
- **Get specific comment**: `GET /repos/{owner}/{repo}/pulls/comments/{comment_id}`

#### Write Operations: CRITICAL - Edit vs Reply Distinction

**⚠️ IMPORTANT**: Understanding the difference between EDITING and REPLYING is critical for safe operations:

**EDIT Comment (Modify Existing)**
- **Endpoint**: `PATCH /repos/{owner}/{repo}/pulls/comments/{comment_id}`
- **Purpose**: Modifies existing comment content
- **Permission**: Must be comment author OR repository admin
- **Effect**: Updates existing comment, preserves ID, shows edit history
- **Use case**: Fix typos, correct information, update suggestions

**REPLY to Comment (Create New)**
- **Endpoint**: `POST /repos/{owner}/{repo}/pulls/{pull_number}/comments/{comment_id}/replies`
- **Purpose**: Creates new comment in thread
- **Permission**: Any collaborator with repository access
- **Effect**: Creates new comment with unique ID, forms conversation thread
- **Use case**: Respond to questions, acknowledge feedback, continue discussion

**⚠️ Safety Warning**: Always verify which operation you intend before proceeding!

#### Using GitHub CLI

**Read Operations:**
```bash
# Get PR review comments (inline comments)
gh api repos/OWNER/REPO/pulls/PR_NUMBER/comments

# Get PR reviews 
gh api repos/OWNER/REPO/pulls/PR_NUMBER/reviews

# Get general PR comments (issue comments)
gh api repos/OWNER/REPO/issues/PR_NUMBER/comments

# Get specific comment details
gh api repos/OWNER/REPO/pulls/comments/COMMENT_ID
```

**Write Operations:**
```bash
# EDIT existing comment (modifies content)
gh api repos/OWNER/REPO/pulls/comments/COMMENT_ID \
  -X PATCH \
  -f body="Updated comment content"

# REPLY to comment (creates new comment)
gh api repos/OWNER/REPO/pulls/PR_NUMBER/comments/COMMENT_ID/replies \
  -X POST \
  -f body="Reply content"
```

**Important**: The `pulls/comments` and `issues/comments` endpoints return different types of comments. You need both to get all comments on a PR.

## Data Structure

### Pull Request Review Comment Schema

```json
{
  "url": "https://api.github.com/repos/octocat/Hello-World/pulls/comments/1",
  "pull_request_review_id": 42,
  "id": 10,
  "node_id": "MDI0OlB1bGxSZXF1ZXN0UmV2aWV3Q29tbWVudDEw",
  "diff_hunk": "@@ -16,33 +16,40 @@ public class Connection : IConnection...",
  "path": "src/main.js",
  "position": 1,
  "original_position": 4,
  "commit_id": "6dcb09b5b57875f334f61aebed695e2e4193db5e",
  "original_commit_id": "9c48853fa3dc5c1c3d6f1f1cd1f2743e72652840",
  "in_reply_to_id": 8,
  "user": {
    "login": "octocat",
    "id": 1,
    "avatar_url": "https://github.com/images/error/octocat_happy.gif",
    "type": "User",
    "site_admin": false
  },
  "body": "Great stuff!",
  "created_at": "2011-04-14T16:00:49Z",
  "updated_at": "2011-04-14T16:00:49Z",
  "html_url": "https://github.com/octocat/Hello-World/pull/1#discussion-diff-1",
  "pull_request_url": "https://api.github.com/repos/octocat/Hello-World/pulls/1",
  "author_association": "OWNER",
  "start_line": 1,
  "original_start_line": 1,
  "start_side": "RIGHT",
  "line": 2,
  "original_line": 2,
  "side": "RIGHT"
}
```

### Key Fields Explained

| Field | Description |
|-------|-------------|
| `id` | Unique identifier for the comment |
| `path` | File path where the comment is made |
| `line` | Line number in the diff |
| `position` | Position in the diff |
| `body` | The comment text |
| `user.login` | Username who made the comment |
| `created_at` | When the comment was created |
| `in_reply_to_id` | ID of parent comment (for threaded discussions) |
| `diff_hunk` | The diff context around the comment |
| `side` | Which side of the diff (LEFT/RIGHT) |
| `pull_request_review_id` | Associated review ID |

### Pull Request Review Schema

```json
{
  "id": 80,
  "node_id": "MDE3OlB1bGxSZXF1ZXN0UmV2aWV3ODA=",
  "user": {
    "login": "octocat",
    "id": 1
  },
  "body": "Here is the body for the review.",
  "state": "APPROVED",
  "html_url": "https://github.com/octocat/Hello-World/pull/12#pullrequestreview-80",
  "pull_request_url": "https://api.github.com/repos/octocat/Hello-World/pulls/12",
  "submitted_at": "2019-11-17T17:43:43Z",
  "commit_id": "ecdd80bb57125d7ba9641ffaa4d7d2c19d3f3091",
  "author_association": "COLLABORATOR"
}
```

## Practical Examples

### Basic Usage

#### 1. Get All Review Comments

```bash
# Basic command
gh api repos/octocat/Hello-World/pulls/37/comments

# With error handling
gh api repos/octocat/Hello-World/pulls/37/comments 2>/dev/null || echo "No review comments found"
```

#### 2. Get Formatted Output

```bash
# Extract key information
gh api repos/octocat/Hello-World/pulls/37/comments | \
jq '.[] | {
  user: .user.login,
  body: .body,
  file: .path,
  line: .line,
  created: .created_at
}'
```

#### 3. Get Comment Count by User

```bash
gh api repos/octocat/Hello-World/pulls/37/comments | \
jq 'group_by(.user.login) | map({user: .[0].user.login, count: length})'
```

### Advanced Filtering with jq

#### Filter Comments by User

```bash
gh api repos/OWNER/REPO/pulls/37/comments | \
jq '.[] | select(.user.login == "specific-user")'
```

#### Filter Comments by File

```bash
gh api repos/OWNER/REPO/pulls/37/comments | \
jq '.[] | select(.path == "src/main.js")'
```

#### Filter Comments by Date Range

```bash
# Comments from last 7 days
gh api repos/OWNER/REPO/pulls/37/comments | \
jq --arg date "$(date -d '7 days ago' -Iseconds)" \
'.[] | select(.created_at > $date)'
```

#### Filter Comments Containing Specific Text

```bash
gh api repos/OWNER/REPO/pulls/37/comments | \
jq '.[] | select(.body | contains("LGTM"))'
```

#### Get Thread Structure

```bash
# Show comment threads (replies)
gh api repos/OWNER/REPO/pulls/37/comments | \
jq '.[] | {
  id: .id,
  reply_to: .in_reply_to_id,
  user: .user.login,
  body: .body
} | select(.reply_to != null)'
```

## Pagination Handling

### GitHub CLI Pagination

GitHub CLI provides built-in pagination support:

```bash
# Get all pages automatically
gh api --paginate repos/OWNER/REPO/pulls/37/comments

# Combine all pages into single array
gh api --paginate --slurp repos/OWNER/REPO/pulls/37/comments
```

### Manual Pagination with curl

```bash
#!/bin/bash
API='https://api.github.com'
OWNER='octocat'
REPO='Hello-World'
PR_NUMBER='37'
TOKEN='your-token'
per_page=100
page=1

while true; do
  response=$(curl -s \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $TOKEN" \
    "${API}/repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/comments?per_page=${per_page}&page=${page}")
  
  # Check if response is empty array
  if [ "$(echo "$response" | jq '. | length')" -eq 0 ]; then
    break
  fi
  
  echo "$response" | jq '.[]'
  ((page++))
done
```

### Handling Large Result Sets

```bash
# Stream processing for large PRs
gh api --paginate repos/OWNER/REPO/pulls/37/comments | \
jq -c '.[]' | \
while IFS= read -r comment; do
  # Process each comment individually
  echo "$comment" | jq '.user.login + ": " + .body'
done
```

## Error Handling

### Common Error Scenarios

1. **No review comments exist**: Returns empty array `[]`
2. **Invalid PR number**: Returns 404 error
3. **No access to repository**: Returns 403/404 error
4. **Rate limiting**: Returns 403 with rate limit headers

### Error Handling Examples

```bash
# Check if PR exists first
if gh api repos/OWNER/REPO/pulls/37 >/dev/null 2>&1; then
  comments=$(gh api repos/OWNER/REPO/pulls/37/comments)
  if [ "$comments" = "[]" ]; then
    echo "No review comments found"
  else
    echo "$comments" | jq '.[] | .body'
  fi
else
  echo "PR not found or no access"
fi
```

### Rate Limiting Considerations

```bash
# Check rate limit status
gh api rate_limit | jq '.rate'

# Handle rate limiting in scripts
check_rate_limit() {
  remaining=$(gh api rate_limit | jq '.rate.remaining')
  if [ "$remaining" -lt 10 ]; then
    reset_time=$(gh api rate_limit | jq '.rate.reset')
    echo "Rate limit low. Resets at: $(date -d @$reset_time)"
    sleep $(( reset_time - $(date +%s) + 10 ))
  fi
}
```

## Authentication Requirements

### GitHub CLI Authentication

```bash
# Authenticate with GitHub CLI
gh auth login

# Check authentication status
gh auth status

# Use specific token
export GITHUB_TOKEN="your-token"
```

### Permissions Required

#### Read Operations

To read PR review comments, you need:

- **Public repositories**: No authentication required for public repos
- **Private repositories**: Read access to the repository
- **Organization repositories**: Member or collaborator access

#### Write Operations (Edit vs Reply)

**EDIT Comment Permissions:**
- **Comment Author**: Can always edit their own comments
- **Repository Admin**: Can edit any comment in the repository
- **Organization Owner**: Can edit comments in organization repositories
- **⚠️ Restriction**: Regular collaborators CANNOT edit comments by others

**REPLY Comment Permissions:**
- **Any Collaborator**: Anyone with read/write access to repository
- **Repository Members**: All members of the repository
- **Organization Members**: Members with appropriate repository access
- **⚠️ Note**: Much more permissive than edit operations

#### Permission Validation Example

```bash
# Check if you can edit a specific comment
check_edit_permission() {
  local comment_id="$1"
  local current_user=$(gh api user --jq '.login')
  local comment_author=$(gh api repos/$OWNER/$REPO/pulls/comments/$comment_id --jq '.user.login')
  
  if [ "$current_user" = "$comment_author" ]; then
    echo "✅ You can edit this comment (you are the author)"
  else
    echo "❌ You cannot edit this comment (not the author)"
  fi
}
```

## Comparison: Review Comments vs Issue Comments

| Aspect | Review Comments | Issue Comments |
|--------|----------------|----------------|
| **Endpoint** | `/pulls/{pr}/comments` | `/issues/{issue}/comments` |
| **Location** | Specific lines in diff | General PR discussion |
| **Fields** | `path`, `line`, `diff_hunk` | No file/line context |
| **Threading** | `in_reply_to_id` | No threading |
| **Purpose** | Code review feedback | General discussion |

### Getting Both Types

```bash
# Script to get all comments on a PR
get_all_pr_comments() {
  local owner=$1
  local repo=$2
  local pr_number=$3
  
  echo "=== Review Comments (Inline) ===" 
  gh api repos/$owner/$repo/pulls/$pr_number/comments | \
  jq '.[] | {type: "review", user: .user.login, body: .body, file: .path, line: .line}'
  
  echo "=== Issue Comments (General) ==="
  gh api repos/$owner/$repo/issues/$pr_number/comments | \
  jq '.[] | {type: "issue", user: .user.login, body: .body}'
}

get_all_pr_comments "octocat" "Hello-World" "37"
```

## GitHub CLI Limitations

### Current Limitations

1. **No built-in inline comment display**: `gh pr view --comments` doesn't show review comments
2. **No built-in threading**: CLI doesn't display comment threads visually
3. **Limited formatting options**: Basic JSON output only
4. **No interactive features**: Can't reply to comments directly

### Workarounds

```bash
# Custom formatting function
format_review_comments() {
  gh api repos/$1/$2/pulls/$3/comments | jq -r '
    .[] | 
    "👤 \(.user.login) commented on \(.path):\(.line // "general")
    💬 \(.body)
    📅 \(.created_at)
    ---"
  '
}

format_review_comments "owner" "repo" "123"
```

## GraphQL API Alternative

For complex queries, consider using GitHub's GraphQL API:

```bash
# GraphQL query for PR review comments
gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        reviews(first: 100) {
          nodes {
            author {
              login
            }
            body
            state
            comments(first: 100) {
              nodes {
                body
                path
                line
                author {
                  login
                }
                createdAt
              }
            }
          }
        }
      }
    }
  }
' -f owner=OWNER -f repo=REPO -F number=123
```

## Best Practices

### 1. Efficient Data Retrieval

```bash
# Use pagination for large PRs
gh api --paginate repos/OWNER/REPO/pulls/PR/comments

# Filter early to reduce processing
gh api repos/OWNER/REPO/pulls/PR/comments | \
jq '.[] | select(.user.login == "target-user")'
```

### 2. Caching for Multiple Operations

```bash
# Cache results for multiple operations
COMMENTS_FILE="/tmp/pr_comments_${PR_NUMBER}.json"
if [ ! -f "$COMMENTS_FILE" ] || [ $(($(date +%s) - $(stat -c %Y "$COMMENTS_FILE"))) -gt 300 ]; then
  gh api repos/OWNER/REPO/pulls/$PR_NUMBER/comments > "$COMMENTS_FILE"
fi

# Use cached data
jq '.[] | select(.user.login == "user1")' "$COMMENTS_FILE"
jq '.[] | select(.path == "src/main.js")' "$COMMENTS_FILE"
```

### 3. Error Recovery

```bash
# Robust comment fetching with retries
fetch_with_retry() {
  local max_attempts=3
  local attempt=1
  
  while [ $attempt -le $max_attempts ]; do
    if result=$(gh api repos/$1/$2/pulls/$3/comments 2>/dev/null); then
      echo "$result"
      return 0
    fi
    
    echo "Attempt $attempt failed, retrying..." >&2
    sleep $((attempt * 2))
    ((attempt++))
  done
  
  echo "Failed after $max_attempts attempts" >&2
  return 1
}
```

### 4. Processing Large Datasets

```bash
# Stream processing for memory efficiency
gh api --paginate repos/OWNER/REPO/pulls/PR/comments | \
jq -c '.[]' | \
while IFS= read -r comment; do
  # Process one comment at a time
  user=$(echo "$comment" | jq -r '.user.login')
  body=$(echo "$comment" | jq -r '.body')
  echo "$user: $body"
done
```

## Summary

This guide provides comprehensive coverage of GitHub PR review comments API access. Key takeaways:

- Use `gh api repos/OWNER/REPO/pulls/PR/comments` for inline review comments
- Use `gh api repos/OWNER/REPO/issues/PR/comments` for general PR discussions  
- Combine jq filtering for powerful data processing
- Handle pagination for large PRs with `--paginate`
- Implement proper error handling and rate limiting
- Consider GraphQL API for complex relational queries

The GitHub CLI provides excellent programmatic access to PR review comments, enabling powerful automation and analysis workflows for code review processes.