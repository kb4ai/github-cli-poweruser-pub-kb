# GitHub PR Review Comments - Conversation Resolution Guide

## Overview

This guide covers how to respond to and resolve GitHub Pull Request review comment conversations using both REST and GraphQL APIs. It includes practical scripts and examples for automating comment responses and conversation resolution.

## Key Concepts

### Comment vs Conversation Thread

- **Review Comment**: An individual comment on a specific line of code in a PR
- **Conversation Thread**: A group of related comments that can be resolved as a unit
- **Resolution**: Marking a conversation thread as "resolved" to indicate the issue has been addressed

### API Differences

- **REST API**: Good for reading comments and posting replies, but lacks conversation resolution
- **GraphQL API**: Required for conversation thread resolution and status management

## Available Scripts

### 1. Reply to Comment (`reply-to-comment.sh`)

Posts a reply to a specific review comment.

**Usage:**
```bash
./reply-to-comment.sh OWNER REPO PR_NUMBER COMMENT_ID "Reply message"
```

**Example:**
```bash
./reply-to-comment.sh FlowCortex flowcortex 107 2172519617 "Thanks for the feedback! I'll address this."
```

**Features:**
- Validates comment exists before posting
- Displays original comment context
- Provides detailed error messages
- Returns reply ID and URL on success

### 2. Resolve Conversation (`resolve-conversation.sh`)

Resolves a conversation thread using GraphQL API.

**Usage:**
```bash
./resolve-conversation.sh OWNER REPO PR_NUMBER COMMENT_ID
```

**Example:**
```bash
./resolve-conversation.sh FlowCortex flowcortex 107 2172519617
```

**Features:**
- Uses GraphQL to find review thread ID from comment ID
- Checks current resolution status
- Provides confirmation before resolving already-resolved threads
- Uses `resolveReviewThread` mutation

### 3. Find, Reply, and Resolve (`find-reply-resolve.sh`)

Comprehensive script that finds comments by text, replies to them, and resolves conversations.

**Usage:**
```bash
./find-reply-resolve.sh OWNER REPO PR_NUMBER SEARCH_TEXT "Reply message"
```

**Example:**
```bash
./find-reply-resolve.sh FlowCortex flowcortex 107 "FOO_BAR_TEST" "Issue addressed, marking as resolved"
```

**Features:**
- Searches for comments containing specific text
- Posts replies to all matching comments
- Resolves all matching conversation threads
- Provides detailed progress reporting
- Handles rate limiting with delays

## Technical Implementation

### Comment Reply API

Uses the REST API endpoint for posting replies:

```bash
POST /repos/{owner}/{repo}/pulls/{pull_number}/comments/{comment_id}/replies
```

**Example:**
```bash
gh api repos/OWNER/REPO/pulls/PR_NUMBER/comments/COMMENT_ID/replies \
  -X POST \
  -f body="Reply message"
```

### Conversation Resolution API

Uses GraphQL API with two steps:

1. **Find Review Thread ID:**
```graphql
query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          comments(first: 100) {
            nodes {
              databaseId
            }
          }
        }
      }
    }
  }
}
```

2. **Resolve Thread:**
```graphql
mutation($threadId: ID!) {
  resolveReviewThread(input: {threadId: $threadId}) {
    thread {
      id
      isResolved
    }
  }
}
```

## Permissions Required

### For Posting Replies
- **Repository access**: Read access to the repository
- **Comment permissions**: Write access to post comments

### For Resolving Conversations
- **Repository access**: Write access to the repository
- **Review permissions**: Ability to resolve review threads
- **GraphQL API access**: Valid GitHub token with appropriate scopes

## Error Handling

### Common Issues

1. **"Resource not accessible by integration"**
   - Insufficient permissions
   - Need write access to repository

2. **"Comment not found"**
   - Invalid comment ID
   - Comment may have been deleted

3. **"Thread already resolved"**
   - Conversation was previously resolved
   - Scripts provide confirmation prompts

4. **Rate limiting**
   - API calls are rate-limited
   - Scripts include delays between operations

### Best Practices

1. **Validate inputs**: Always check comment exists before processing
2. **Handle permissions gracefully**: Provide clear error messages
3. **Use rate limiting**: Add delays between batch operations
4. **Confirm destructive actions**: Ask before resolving already-resolved threads
5. **Provide feedback**: Show progress and results clearly

## Integration Examples

### Automated Response to Test Comments

```bash
# Find and resolve all FOO_BAR_TEST comments
./find-reply-resolve.sh MyOrg MyRepo 123 "FOO_BAR_TEST" "Test comment processed and resolved"
```

### Batch Processing

```bash
#!/bin/bash
# Process multiple PRs
PR_NUMBERS=(107 108 109)
for pr in "${PR_NUMBERS[@]}"; do
    echo "Processing PR #$pr"
    ./find-reply-resolve.sh FlowCortex flowcortex "$pr" "TODO" "Addressed in latest commit"
    sleep 5  # Rate limiting
done
```

### CI/CD Integration

```yaml
# GitHub Actions workflow
name: Auto-resolve Review Comments
on:
  pull_request_review_comment:
    types: [created]

jobs:
  auto-resolve:
    if: contains(github.event.comment.body, '@bot resolve')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Resolve comment
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          ./scripts/resolve-conversation.sh \
            ${{ github.repository_owner }} \
            ${{ github.event.repository.name }} \
            ${{ github.event.pull_request.number }} \
            ${{ github.event.comment.id }}
```

## Verification

After using these scripts, verify the results:

1. **Check PR in GitHub Web Interface**: Navigate to the PR and confirm threads are resolved
2. **Use Basic Comment Reader**: Run `./basic-comment-reader.sh` to see current comment status
3. **GraphQL Query**: Query review threads to verify resolution status

## Limitations

1. **REST API**: Cannot resolve conversations (GraphQL required)
2. **Permissions**: Need write access for resolution operations
3. **Rate Limiting**: GitHub API has rate limits for automated operations
4. **Thread Discovery**: Finding thread ID from comment ID requires GraphQL query

## Troubleshooting

### Script Debugging

Enable verbose output:
```bash
set -x  # Add to top of script for debug mode
```

### API Testing

Test API access:
```bash
# Test GraphQL access
gh api graphql -f query='{ viewer { login } }'

# Test repository access
gh api repos/OWNER/REPO
```

### Permission Verification

Check repository permissions:
```bash
gh api repos/OWNER/REPO/collaborators/USERNAME/permission
```

This comprehensive guide provides everything needed to programmatically manage GitHub PR review comment conversations, from simple replies to complete resolution workflows.