# Advanced GitHub PR Review Comments Features

## Overview

This document covers advanced features for GitHub PR review comment automation, including posting replies, batch operations, webhook integration, and GitHub Actions workflows.

## Posting Replies to Review Comments

### API Endpoint for Replies

GitHub provides a specific API endpoint for replying to existing review comments:

```
POST /repos/{owner}/{repo}/pulls/{pull_number}/comments/{comment_id}/replies
```

### Using GitHub CLI to Post Replies

```bash
# Reply to a specific review comment
gh api repos/OWNER/REPO/pulls/PR_NUMBER/comments/COMMENT_ID/replies \
  -X POST \
  -f body="Great point! I'll address this in the next commit."

# Reply with formatted message
gh api repos/OWNER/REPO/pulls/PR_NUMBER/comments/COMMENT_ID/replies \
  -X POST \
  -f body="$(cat <<'EOF'
Thanks for the feedback! 

I've updated the code to:
- Add proper error handling
- Include unit tests
- Update documentation

Could you review the changes?
EOF
)"
```

### Script for Automated Replies

```bash
#!/bin/bash
# reply-to-comment.sh
# Usage: ./reply-to-comment.sh OWNER REPO PR_NUMBER COMMENT_ID "Reply message"

set -e

OWNER="$1"
REPO="$2"
PR_NUMBER="$3"
COMMENT_ID="$4"
REPLY_MESSAGE="$5"

if [ $# -ne 5 ]; then
    echo "Usage: $0 OWNER REPO PR_NUMBER COMMENT_ID 'Reply message'"
    exit 1
fi

# Validate comment exists
if ! gh api repos/"$OWNER"/"$REPO"/pulls/"$PR_NUMBER"/comments/"$COMMENT_ID" >/dev/null 2>&1; then
    echo "Error: Comment not found"
    exit 1
fi

# Post reply
response=$(gh api repos/"$OWNER"/"$REPO"/pulls/"$PR_NUMBER"/comments/"$COMMENT_ID"/replies \
  -X POST \
  -f body="$REPLY_MESSAGE")

echo "Reply posted successfully!"
echo "Reply ID: $(echo "$response" | jq -r '.id')"
echo "URL: $(echo "$response" | jq -r '.html_url')"
```

### Batch Reply Operations

```bash
#!/bin/bash
# batch-reply.sh - Reply to multiple comments with same message

OWNER="$1"
REPO="$2"
PR_NUMBER="$3"
REPLY_MESSAGE="$4"

# Get all comments that need replies (example: comments containing "TODO")
comments_to_reply=$(gh api repos/"$OWNER"/"$REPO"/pulls/"$PR_NUMBER"/comments | \
  jq -r '.[] | select(.body | contains("TODO")) | .id')

for comment_id in $comments_to_reply; do
    echo "Replying to comment ID: $comment_id"
    gh api repos/"$OWNER"/"$REPO"/pulls/"$PR_NUMBER"/comments/"$comment_id"/replies \
      -X POST \
      -f body="$REPLY_MESSAGE"
    sleep 1  # Avoid rate limiting
done
```

## Creating Review Comments Programmatically

### Single Line Comments

```bash
# Create a review comment on a specific line
gh api repos/OWNER/REPO/pulls/PR_NUMBER/comments \
  -X POST \
  -f body="This function could be optimized for better performance." \
  -f commit_id="$(gh api repos/OWNER/REPO/pulls/PR_NUMBER | jq -r '.head.sha')" \
  -f path="src/main.js" \
  -F line=42
```

### Multi-line Comments

```bash
# Create a comment spanning multiple lines
gh api repos/OWNER/REPO/pulls/PR_NUMBER/comments \
  -X POST \
  -f body="Consider refactoring this entire block for better readability." \
  -f commit_id="$(gh api repos/OWNER/REPO/pulls/PR_NUMBER | jq -r '.head.sha')" \
  -f path="src/main.js" \
  -F start_line=40 \
  -F line=45 \
  -f side="RIGHT"
```

### Bulk Review Comments

```bash
#!/bin/bash
# bulk-review-comments.sh - Create multiple review comments from a CSV file

# CSV format: file_path,line_number,comment_body
# Example: src/main.js,42,This needs error handling

OWNER="$1"
REPO="$2"
PR_NUMBER="$3"
CSV_FILE="$4"

commit_sha=$(gh api repos/"$OWNER"/"$REPO"/pulls/"$PR_NUMBER" | jq -r '.head.sha')

while IFS=',' read -r file_path line_number comment_body; do
    echo "Adding comment to $file_path:$line_number"
    
    gh api repos/"$OWNER"/"$REPO"/pulls/"$PR_NUMBER"/comments \
      -X POST \
      -f body="$comment_body" \
      -f commit_id="$commit_sha" \
      -f path="$file_path" \
      -F line="$line_number"
    
    sleep 1  # Rate limiting
done < "$CSV_FILE"
```

## Webhook Integration

### Creating Webhooks with GitHub CLI

```bash
# Create webhook for PR review comments
webhook_payload=$(cat <<'EOF'
{
  "name": "web",
  "active": true,
  "events": [
    "pull_request_review_comment",
    "pull_request_review",
    "pull_request"
  ],
  "config": {
    "url": "https://your-webhook-endpoint.com/github",
    "content_type": "json",
    "insecure_ssl": "0",
    "secret": "your-webhook-secret"
  }
}
EOF
)

echo "$webhook_payload" | gh api repos/OWNER/REPO/hooks -X POST --input -
```

### Webhook Event Types

Key webhook events for PR review comments:

- `pull_request_review_comment`: Triggered when a review comment is created, edited, or deleted
- `pull_request_review`: Triggered when a review is submitted, edited, or dismissed
- `pull_request`: Triggered for various PR events

### Webhook Payload Processing

```bash
#!/bin/bash
# webhook-processor.sh - Process incoming webhook payloads

process_review_comment() {
    local payload="$1"
    
    action=$(echo "$payload" | jq -r '.action')
    comment_body=$(echo "$payload" | jq -r '.comment.body')
    comment_author=$(echo "$payload" | jq -r '.comment.user.login')
    pr_number=$(echo "$payload" | jq -r '.pull_request.number')
    
    case "$action" in
        "created")
            echo "New review comment by $comment_author on PR #$pr_number"
            # Process new comment
            ;;
        "edited")
            echo "Review comment edited by $comment_author on PR #$pr_number"
            # Process edited comment
            ;;
        "deleted")
            echo "Review comment deleted by $comment_author on PR #$pr_number"
            # Process deleted comment
            ;;
    esac
}

# Read webhook payload from stdin
payload=$(cat)
event_type=$(echo "$payload" | jq -r '.action')

case "$event_type" in
    "pull_request_review_comment")
        process_review_comment "$payload"
        ;;
    *)
        echo "Unhandled event type: $event_type"
        ;;
esac
```

## GitHub Actions Integration

### Workflow for PR Review Comment Automation

```yaml
# .github/workflows/pr-review-automation.yml
name: PR Review Comment Automation

on:
  pull_request_review_comment:
    types: [created, edited]
  pull_request_review:
    types: [submitted]

jobs:
  process-review-comments:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Process review comment
      uses: actions/github-script@v7
      with:
        script: |
          const comment = context.payload.comment;
          const pr = context.payload.pull_request;
          
          // Auto-reply to specific comment patterns
          if (comment && comment.body.includes('@bot help')) {
            await github.rest.pulls.createReviewComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              pull_number: pr.number,
              commit_id: pr.head.sha,
              path: comment.path,
              line: comment.line,
              body: 'Here are the available commands:\n- `@bot format` - Format code\n- `@bot test` - Run tests\n- `@bot docs` - Generate docs'
            });
          }
          
          // Auto-approve dependabot PRs
          if (pr.user.login === 'dependabot[bot]' && comment.body.includes('LGTM')) {
            await github.rest.pulls.createReview({
              owner: context.repo.owner,
              repo: context.repo.repo,
              pull_number: pr.number,
              event: 'APPROVE',
              body: 'Auto-approved dependabot PR ✅'
            });
          }
```

### Comment-Triggered Workflows

```yaml
# .github/workflows/comment-commands.yml
name: Comment Commands

on:
  issue_comment:
    types: [created]

jobs:
  handle-comment-commands:
    if: github.event.issue.pull_request
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4
    
    - name: Handle deploy command
      if: contains(github.event.comment.body, '/deploy')
      run: |
        echo "Deploying PR #${{ github.event.issue.number }}"
        # Add deployment logic here
    
    - name: Handle test command
      if: contains(github.event.comment.body, '/test')
      run: |
        echo "Running tests for PR #${{ github.event.issue.number }}"
        # Add test logic here
    
    - name: Reply to comment
      uses: actions/github-script@v7
      with:
        script: |
          const comment = context.payload.comment;
          
          let replyBody = '';
          if (comment.body.includes('/deploy')) {
            replyBody = '🚀 Deployment initiated!';
          } else if (comment.body.includes('/test')) {
            replyBody = '🧪 Tests started!';
          }
          
          if (replyBody) {
            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: replyBody
            });
          }
```

### Automated Review Summary

```yaml
# .github/workflows/review-summary.yml
name: Review Summary

on:
  pull_request:
    types: [closed]

jobs:
  generate-summary:
    if: github.event.pull_request.merged == true
    runs-on: ubuntu-latest
    
    steps:
    - name: Generate review summary
      uses: actions/github-script@v7
      with:
        script: |
          const { data: comments } = await github.rest.pulls.listReviewComments({
            owner: context.repo.owner,
            repo: context.repo.repo,
            pull_number: context.issue.number
          });
          
          const commentStats = comments.reduce((acc, comment) => {
            acc[comment.user.login] = (acc[comment.user.login] || 0) + 1;
            return acc;
          }, {});
          
          const summary = Object.entries(commentStats)
            .map(([user, count]) => `- ${user}: ${count} comments`)
            .join('\n');
          
          await github.rest.issues.createComment({
            owner: context.repo.owner,
            repo: context.repo.repo,
            issue_number: context.issue.number,
            body: `## Review Summary 📊\n\n${summary}\n\nTotal comments: ${comments.length}`
          });
```

## Real-time Monitoring

### Webhook Server Example

```bash
#!/bin/bash
# webhook-server.sh - Simple webhook server using nc

PORT=8080

echo "Starting webhook server on port $PORT..."

while true; do
    # Listen for incoming webhooks
    request=$(echo -e "HTTP/1.1 200 OK\r\n\r\nOK" | nc -l -p $PORT)
    
    # Extract JSON payload
    payload=$(echo "$request" | sed -n '/^{/,$p')
    
    if [ -n "$payload" ]; then
        echo "Received webhook payload:"
        echo "$payload" | jq '.'
        
        # Process the payload
        ./webhook-processor.sh <<< "$payload"
    fi
done
```

### Real-time Comment Monitoring

```bash
#!/bin/bash
# monitor-comments.sh - Monitor new comments in real-time

OWNER="$1"
REPO="$2"
PR_NUMBER="$3"
INTERVAL="${4:-30}"  # seconds

last_comment_id=""

while true; do
    # Get latest comment
    latest_comment=$(gh api repos/"$OWNER"/"$REPO"/pulls/"$PR_NUMBER"/comments | \
      jq -r 'sort_by(.created_at) | last')
    
    if [ "$latest_comment" != "null" ]; then
        current_id=$(echo "$latest_comment" | jq -r '.id')
        
        if [ "$current_id" != "$last_comment_id" ]; then
            echo "New comment detected!"
            echo "$latest_comment" | jq -r '
              "User: \(.user.login)
              File: \(.path):\(.line)
              Comment: \(.body)
              Time: \(.created_at)
              URL: \(.html_url)"
            '
            echo "---"
            
            last_comment_id="$current_id"
        fi
    fi
    
    sleep "$INTERVAL"
done
```

## Integration with External Tools

### Slack Integration

```bash
#!/bin/bash
# slack-notify.sh - Send review comments to Slack

SLACK_WEBHOOK="$1"
OWNER="$2"
REPO="$3"
PR_NUMBER="$4"

# Get recent comments (last hour)
cutoff_time=$(date -d '1 hour ago' -Iseconds)

recent_comments=$(gh api repos/"$OWNER"/"$REPO"/pulls/"$PR_NUMBER"/comments | \
  jq --arg cutoff "$cutoff_time" '.[] | select(.created_at > $cutoff)')

if [ "$recent_comments" != "" ]; then
    slack_message=$(echo "$recent_comments" | jq -r '
      "New review comment on PR #'$PR_NUMBER':
      👤 *\(.user.login)* commented on `\(.path):\(.line)`
      💬 \(.body)
      🔗 <\(.html_url)|View on GitHub>"
    ')
    
    curl -X POST -H 'Content-type: application/json' \
      --data "{\"text\":\"$slack_message\"}" \
      "$SLACK_WEBHOOK"
fi
```

### Email Notifications

```bash
#!/bin/bash
# email-notify.sh - Email notifications for review comments

EMAIL_TO="$1"
OWNER="$2"
REPO="$3"
PR_NUMBER="$4"

# Get comments from last hour
cutoff_time=$(date -d '1 hour ago' -Iseconds)

comments=$(gh api repos/"$OWNER"/"$REPO"/pulls/"$PR_NUMBER"/comments | \
  jq --arg cutoff "$cutoff_time" '.[] | select(.created_at > $cutoff)')

if [ "$comments" != "" ]; then
    # Generate email content
    email_content=$(echo "$comments" | jq -r '
      "Subject: New PR Review Comments - #'$PR_NUMBER'
      
      New review comments on PR #'$PR_NUMBER' in '$OWNER'/'$REPO':
      
      User: \(.user.login)
      File: \(.path):\(.line)
      Comment: \(.body)
      Time: \(.created_at)
      Link: \(.html_url)
      
      ---"
    ')
    
    echo "$email_content" | sendmail "$EMAIL_TO"
fi
```

## Best Practices for Advanced Features

### 1. Rate Limiting Management

```bash
# Check rate limits before batch operations
check_rate_limit() {
    remaining=$(gh api rate_limit | jq '.rate.remaining')
    if [ "$remaining" -lt 100 ]; then
        echo "Rate limit low ($remaining remaining), waiting..."
        reset_time=$(gh api rate_limit | jq '.rate.reset')
        sleep $(( reset_time - $(date +%s) + 60 ))
    fi
}

# Use in batch operations
for comment_id in "${comment_ids[@]}"; do
    check_rate_limit
    # Make API call
done
```

### 2. Error Handling and Retries

```bash
# Robust API call with retries
api_call_with_retry() {
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if result=$(gh api "$@" 2>/dev/null); then
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

### 3. Structured Logging

```bash
# Structured logging for automation
log_action() {
    local level="$1"
    local action="$2"
    local details="$3"
    
    timestamp=$(date -Iseconds)
    
    echo "{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"action\":\"$action\",\"details\":\"$details\"}" >&2
}

# Usage
log_action "INFO" "comment_created" "Reply posted to comment ID 123"
log_action "ERROR" "api_call_failed" "Failed to fetch PR comments"
```

## Security Considerations

### Token Management

```bash
# Use GitHub CLI's built-in token management
gh auth status

# Or use environment variables securely
export GITHUB_TOKEN="$(cat ~/.github_token)"

# Validate token has required permissions
gh api user | jq -r '.login' || {
    echo "Invalid token"
    exit 1
}
```

### Input Validation

```bash
# Validate inputs to prevent injection
validate_input() {
    local input="$1"
    local pattern="$2"
    
    if [[ ! "$input" =~ $pattern ]]; then
        echo "Invalid input: $input"
        exit 1
    fi
}

# Usage
validate_input "$PR_NUMBER" '^[0-9]+$'
validate_input "$OWNER" '^[a-zA-Z0-9_-]+$'
```

This comprehensive guide provides the foundation for building sophisticated GitHub PR review comment automation systems using GitHub CLI, webhooks, and GitHub Actions.