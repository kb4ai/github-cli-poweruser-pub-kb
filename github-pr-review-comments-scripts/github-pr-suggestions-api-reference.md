# GitHub PR Suggestions - API Reference

Comprehensive technical reference for GitHub Pull Request suggestions API endpoints, authentication, and implementation details.

## Table of Contents

- [API Overview](#api-overview)
- [Authentication](#authentication)
- [REST API Endpoints](#rest-api-endpoints)
- [GraphQL API](#graphql-api)
- [Response Formats](#response-formats)
- [Error Handling](#error-handling)
- [Rate Limiting](#rate-limiting)
- [Best Practices](#best-practices)
- [Code Examples](#code-examples)

## API Overview

GitHub PR suggestions are implemented as special review comments with markdown formatting. There are no dedicated "suggestion" endpoints - suggestions use the existing Pull Request Review Comments API with specific markdown syntax.

### Key Concepts

- **Suggestions are review comments**: They use the PR review comments API
- **Special markdown format**: Comments with `````suggestion` blocks
- **Position-based**: Target specific lines in the diff
- **Immutable**: Cannot be edited once created (delete and recreate)
- **UI-only acceptance**: Must be accepted through GitHub web interface

### Suggestion Lifecycle

1. **Create**: POST review comment with suggestion markdown
2. **Read**: GET review comments and filter for suggestion blocks  
3. **Update**: Not supported (delete and recreate)
4. **Delete**: DELETE the review comment
5. **Accept**: UI-only operation (no API support)

## Authentication

### Required Permissions

For **reading** suggestions:
- Public repositories: No authentication required
- Private repositories: `repo` or `public_repo` scope

For **creating/deleting** suggestions:
- All repositories: `repo` scope (write access)

### Authentication Methods

#### Personal Access Token
```bash
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"
gh auth login --with-token <<< "$GITHUB_TOKEN"
```

#### GitHub App
```bash
# Use installation access token
curl -H "Authorization: Bearer $INSTALLATION_TOKEN" \
     -H "Accept: application/vnd.github+json" \
     https://api.github.com/repos/owner/repo/pulls/123/comments
```

#### OAuth App
```bash
# Use OAuth token
curl -H "Authorization: token $OAUTH_TOKEN" \
     https://api.github.com/repos/owner/repo/pulls/123/comments
```

## REST API Endpoints

### Create Review Comment with Suggestion

Create a suggestion by posting a review comment with special markdown.

**Endpoint:**
```
POST /repos/{owner}/{repo}/pulls/{pull_number}/comments
```

**Parameters:**
- `owner` (string, required): Repository owner
- `repo` (string, required): Repository name  
- `pull_number` (integer, required): Pull request number

**Request Body:**
```json
{
  "body": "string (required) - Comment body with suggestion markdown",
  "commit_id": "string (required) - SHA of the commit to comment on",
  "path": "string (required) - Relative path of file to comment on",
  "position": "integer (optional) - Position in diff (line number)",
  "line": "integer (optional) - Line number in file",
  "side": "string (optional) - LEFT or RIGHT side of diff"
}
```

**Example Request:**
```bash
curl -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/owner/repo/pulls/123/comments \
  -d '{
    "body": "Fix variable name\n\n```suggestion\nconst userName = \"john\";\n```",
    "commit_id": "6dcb09b5b57875f334f61aebed695e2e4193db5e",
    "path": "src/main.js",
    "position": 15
  }'
```

**Response (201 Created):**
```json
{
  "id": 12345678,
  "node_id": "MDI0OlB1bGxSZXF1ZXN0UmV2aWV3Q29tbWVudDEyMzQ1Njc4",
  "url": "https://api.github.com/repos/owner/repo/pulls/comments/12345678",
  "html_url": "https://github.com/owner/repo/pull/123#issuecomment-12345678",
  "body": "Fix variable name\n\n```suggestion\nconst userName = \"john\";\n```",
  "path": "src/main.js",
  "position": 15,
  "line": 10,
  "commit_id": "6dcb09b5b57875f334f61aebed695e2e4193db5e",
  "user": {
    "login": "reviewer",
    "id": 987654,
    "type": "User"
  },
  "created_at": "2023-11-15T10:30:00Z",
  "updated_at": "2023-11-15T10:30:00Z"
}
```

### Create Review with Multiple Suggestions

Create multiple suggestions in a single review.

**Endpoint:**
```
POST /repos/{owner}/{repo}/pulls/{pull_number}/reviews
```

**Request Body:**
```json
{
  "commit_id": "string (required) - SHA of commit",
  "body": "string (optional) - Overall review body",
  "event": "string (required) - APPROVE, REQUEST_CHANGES, or COMMENT",
  "comments": [
    {
      "path": "string (required) - File path",
      "position": "integer (required) - Position in diff", 
      "body": "string (required) - Comment with suggestion"
    }
  ]
}
```

**Example Request:**
```bash
curl -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  https://api.github.com/repos/owner/repo/pulls/123/reviews \
  -d '{
    "commit_id": "6dcb09b5b57875f334f61aebed695e2e4193db5e",
    "body": "Some suggestions for improvement",
    "event": "COMMENT",
    "comments": [
      {
        "path": "src/main.js",
        "position": 15,
        "body": "```suggestion\nconst userName = \"john\";\n```"
      },
      {
        "path": "src/utils.js", 
        "position": 8,
        "body": "```suggestion\nreturn response.data;\n```"
      }
    ]
  }'
```

### List Review Comments

Retrieve all review comments for a pull request.

**Endpoint:**
```
GET /repos/{owner}/{repo}/pulls/{pull_number}/comments
```

**Parameters:**
- `sort` (string): created, updated (default: created)
- `direction` (string): asc, desc (default: asc)
- `since` (string): ISO 8601 timestamp
- `per_page` (integer): Results per page (max 100)
- `page` (integer): Page number

**Example Request:**
```bash
curl -H "Accept: application/vnd.github+json" \
     -H "Authorization: Bearer $GITHUB_TOKEN" \
     https://api.github.com/repos/owner/repo/pulls/123/comments?per_page=100
```

**Filter for Suggestions:**
```bash
# Using jq to filter comments with suggestion blocks
gh api repos/owner/repo/pulls/123/comments --paginate | \
jq '.[] | select(.body | test("```suggestion"))'
```

### Get Specific Review Comment

**Endpoint:**
```
GET /repos/{owner}/{repo}/pulls/comments/{comment_id}
```

**Example:**
```bash
curl -H "Accept: application/vnd.github+json" \
     -H "Authorization: Bearer $GITHUB_TOKEN" \
     https://api.github.com/repos/owner/repo/pulls/comments/12345678
```

### Delete Review Comment

Remove a suggestion by deleting its review comment.

**Endpoint:**
```
DELETE /repos/{owner}/{repo}/pulls/comments/{comment_id}
```

**Example:**
```bash
curl -X DELETE \
     -H "Accept: application/vnd.github+json" \
     -H "Authorization: Bearer $GITHUB_TOKEN" \
     https://api.github.com/repos/owner/repo/pulls/comments/12345678
```

**Response:** 204 No Content (success)

### Get Pull Request Diff

Required for calculating line positions.

**Endpoint:**
```
GET /repos/{owner}/{repo}/pulls/{pull_number}
```

**Headers:**
```
Accept: application/vnd.github.v3.diff
```

**Example:**
```bash
curl -H "Accept: application/vnd.github.v3.diff" \
     -H "Authorization: Bearer $GITHUB_TOKEN" \
     https://api.github.com/repos/owner/repo/pulls/123
```

## GraphQL API

### Schema Objects

#### PullRequestReviewComment
```graphql
type PullRequestReviewComment {
  id: ID!
  body: String!
  path: String!
  position: Int
  originalPosition: Int
  commitId: String!
  createdAt: DateTime!
  updatedAt: DateTime!
  url: URI!
  author: Actor!
  pullRequest: PullRequest!
  replyTo: PullRequestReviewComment
}
```

### Queries

#### Get Review Comments
```graphql
query GetReviewComments($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      reviewThreads(first: 100) {
        nodes {
          comments(first: 100) {
            nodes {
              id
              body
              path
              position
              originalPosition
              createdAt
              author {
                login
              }
            }
          }
        }
      }
    }
  }
}
```

#### Filter for Suggestions
```graphql
query GetSuggestions($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      reviewThreads(first: 100) {
        nodes {
          comments(first: 100) {
            nodes {
              id
              body(renderer: MARKDOWN)
              path
              position
              createdAt
              author {
                login
              }
            }
          }
        }
      }
    }
  }
}
```

### Mutations

#### Add Review Comment
```graphql
mutation AddReviewComment($input: AddPullRequestReviewCommentInput!) {
  addPullRequestReviewComment(input: $input) {
    comment {
      id
      body
      path
      position
      createdAt
      url
    }
  }
}
```

**Input Type:**
```graphql
input AddPullRequestReviewCommentInput {
  pullRequestId: ID!
  body: String!
  path: String!
  position: Int
  commitOid: GitObjectID!
}
```

**Example Variables:**
```json
{
  "input": {
    "pullRequestId": "PR_kwDOABCDEFGHIJKLMN",
    "body": "```suggestion\nconst userName = 'john';\n```",
    "path": "src/main.js",
    "position": 15,
    "commitOid": "6dcb09b5b57875f334f61aebed695e2e4193db5e"
  }
}
```

#### Delete Review Comment
```graphql
mutation DeleteReviewComment($input: DeletePullRequestReviewCommentInput!) {
  deletePullRequestReviewComment(input: $input) {
    pullRequestReviewComment {
      id
    }
  }
}
```

## Response Formats

### Review Comment Object

```json
{
  "id": 12345678,
  "node_id": "MDI0OlB1bGxSZXF1ZXN0UmV2aWV3Q29tbWVudDEyMzQ1Njc4",
  "url": "https://api.github.com/repos/owner/repo/pulls/comments/12345678",
  "html_url": "https://github.com/owner/repo/pull/123#issuecomment-12345678",
  "diff_hunk": "@@ -1,3 +1,3 @@\n line1\n-line2\n+line2_modified\n line3",
  "path": "src/main.js",
  "position": 15,
  "original_position": 15,
  "commit_id": "6dcb09b5b57875f334f61aebed695e2e4193db5e",
  "original_commit_id": "6dcb09b5b57875f334f61aebed695e2e4193db5e",
  "in_reply_to_id": null,
  "user": {
    "login": "reviewer",
    "id": 987654,
    "node_id": "MDQ6VXNlcjk4NzY1NA==",
    "avatar_url": "https://avatars.githubusercontent.com/u/987654?v=4",
    "type": "User",
    "site_admin": false
  },
  "body": "Fix variable name\n\n```suggestion\nconst userName = \"john\";\n```",
  "created_at": "2023-11-15T10:30:00Z",
  "updated_at": "2023-11-15T10:30:00Z",
  "author_association": "COLLABORATOR",
  "start_line": null,
  "original_start_line": null,
  "start_side": null,
  "line": 10,
  "original_line": 10,
  "side": "RIGHT"
}
```

### Error Response Format

```json
{
  "message": "Validation Failed",
  "errors": [
    {
      "resource": "PullRequestReviewComment",
      "field": "position",
      "code": "invalid"
    }
  ],
  "documentation_url": "https://docs.github.com/rest/pulls/comments#create-a-review-comment-for-a-pull-request"
}
```

## Error Handling

### Common Error Codes

#### 404 Not Found
```json
{
  "message": "Not Found",
  "documentation_url": "https://docs.github.com/rest"
}
```

**Causes:**
- Pull request doesn't exist
- Repository doesn't exist or no access
- Invalid comment ID

#### 422 Validation Failed
```json
{
  "message": "Validation Failed",
  "errors": [
    {
      "resource": "PullRequestReviewComment",
      "field": "position",
      "code": "invalid",
      "message": "Position is not valid for this diff"
    }
  ]
}
```

**Causes:**
- Invalid line position
- File path not in PR diff
- Invalid commit ID
- Empty comment body

#### 403 Forbidden
```json
{
  "message": "Forbidden",
  "documentation_url": "https://docs.github.com/rest"
}
```

**Causes:**
- Insufficient permissions
- Repository is private and token lacks access
- Rate limiting

### Error Handling Best Practices

```bash
#!/bin/bash
# Error handling example

handle_api_error() {
  local response="$1"
  local http_code="$2"
  
  case "$http_code" in
    404)
      echo "Error: Resource not found"
      echo "Check PR number and repository access"
      ;;
    422) 
      echo "Error: Validation failed"
      echo "$response" | jq -r '.errors[]? | "Field: \(.field), Code: \(.code), Message: \(.message)"'
      ;;
    403)
      echo "Error: Access forbidden"
      echo "Check token permissions and rate limits"
      ;;
    *)
      echo "HTTP $http_code: $response"
      ;;
  esac
}

# Usage with curl
response=$(curl -s -w "%{http_code}" -o response.json \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  https://api.github.com/repos/owner/repo/pulls/123/comments)

http_code="${response: -3}"
if [ "$http_code" != "200" ]; then
  handle_api_error "$(cat response.json)" "$http_code"
fi
```

## Rate Limiting

### Limits

- **REST API**: 5,000 requests per hour (authenticated)
- **GraphQL API**: 5,000 points per hour  
- **Secondary rate limits**: Additional limits for rapid requests

### Rate Limit Headers

```
X-RateLimit-Limit: 5000
X-RateLimit-Remaining: 4999
X-RateLimit-Reset: 1698765432
X-RateLimit-Used: 1
X-RateLimit-Resource: core
```

### Check Rate Limit

```bash
# REST API
curl -H "Authorization: Bearer $GITHUB_TOKEN" \
     https://api.github.com/rate_limit

# GraphQL API  
curl -X POST -H "Authorization: Bearer $GITHUB_TOKEN" \
     -d '{"query": "query { rateLimit { limit remaining resetAt } }"}' \
     https://api.github.com/graphql
```

### Rate Limiting Strategies

```bash
#!/bin/bash
# Rate limiting example

check_rate_limit() {
  local remaining=$(gh api rate_limit --jq '.rate.remaining')
  local reset=$(gh api rate_limit --jq '.rate.reset')
  
  if [ "$remaining" -lt 10 ]; then
    local wait_time=$((reset - $(date +%s)))
    echo "Rate limit low, waiting ${wait_time}s..."
    sleep "$wait_time"
  fi
}

# Use before making API calls
for suggestion in "${suggestions[@]}"; do
  check_rate_limit
  create_suggestion "$suggestion"
  sleep 1  # Additional safety delay
done
```

## Best Practices

### Position Calculation

Calculating correct line positions is critical for suggestions:

```bash
#!/bin/bash
# Calculate diff position for a line

get_diff_position() {
  local file="$1"
  local line_number="$2"
  local pr_number="$3"
  
  # Get diff
  diff=$(gh api "repos/$OWNER/$REPO/pulls/$pr_number" \
    -H "Accept: application/vnd.github.v3.diff")
  
  # Parse diff to find position
  # This is simplified - real implementation needs proper diff parsing
  echo "$diff" | awk -v file="$file" -v line="$line_number" '
    /^diff --git/ { current_file = $0; gsub(/.*b\//, "", current_file) }
    current_file == file && /^@@/ { 
      split($0, parts, " ")
      start_line = parts[3]
      gsub(/^\+/, "", start_line)
      position = 1
    }
    current_file == file && /^[+\-]/ { 
      if (NR - start_line == line) print position
      position++
    }
  '
}
```

### Batch Operations

```bash
#!/bin/bash
# Efficient batch suggestion creation

create_suggestions_batch() {
  local suggestions_file="$1"
  local batch_size=5
  local count=0
  
  while IFS=',' read -r file line suggestion desc; do
    create_suggestion "$file" "$line" "$suggestion" "$desc" &
    
    count=$((count + 1))
    if [ $((count % batch_size)) -eq 0 ]; then
      wait  # Wait for current batch to complete
      check_rate_limit
    fi
  done < "$suggestions_file"
  
  wait  # Wait for remaining jobs
}
```

### Content Validation

```bash
#!/bin/bash
# Validate suggestion content

validate_suggestion_content() {
  local content="$1"
  
  # Check for null bytes
  if echo "$content" | grep -q $'\x00'; then
    return 1
  fi
  
  # Check length (API has limits)
  if [ ${#content} -gt 65536 ]; then
    return 1
  fi
  
  # Check for proper line endings
  if [[ "$content" =~ $'\r\n' ]]; then
    # Convert CRLF to LF
    content="${content//$'\r\n'/$'\n'}"
  fi
  
  return 0
}
```

## Code Examples

### Shell Script Integration

```bash
#!/bin/bash
# Complete suggestion creation with error handling

create_suggestion_safe() {
  local owner="$1"
  local repo="$2" 
  local pr="$3"
  local file="$4"
  local line="$5"
  local suggestion="$6"
  local description="$7"
  
  # Validate inputs
  if ! validate_inputs "$@"; then
    return 1
  fi
  
  # Get commit SHA
  local commit_sha
  commit_sha=$(gh api "repos/$owner/$repo/pulls/$pr" --jq '.head.sha')
  
  # Calculate position
  local position
  position=$(get_diff_position "$file" "$line" "$pr")
  
  # Create suggestion with retry logic
  local attempts=0
  local max_attempts=3
  
  while [ $attempts -lt $max_attempts ]; do
    if response=$(gh api "repos/$owner/$repo/pulls/$pr/comments" \
      -X POST \
      -f body="$description\n\n\`\`\`suggestion\n$suggestion\n\`\`\`" \
      -f commit_id="$commit_sha" \
      -f path="$file" \
      -F position="$position" 2>&1); then
      
      echo "Suggestion created: $(echo "$response" | jq -r '.html_url')"
      return 0
    fi
    
    attempts=$((attempts + 1))
    echo "Attempt $attempts failed, retrying..."
    sleep $((attempts * 2))
  done
  
  echo "Failed to create suggestion after $max_attempts attempts"
  return 1
}
```

### Python Integration

```python
#!/usr/bin/env python3
"""
GitHub PR Suggestions API Client
"""

import requests
import json
from typing import Optional, Dict, List

class GitHubSuggestionsAPI:
    def __init__(self, token: str):
        self.token = token
        self.base_url = "https://api.github.com"
        self.headers = {
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28"
        }
    
    def create_suggestion(self, owner: str, repo: str, pr_number: int, 
                         file_path: str, position: int, suggestion: str,
                         description: str = "") -> Optional[Dict]:
        """Create a suggestion comment on a PR."""
        
        # Build comment body
        body = f"{description}\n\n```suggestion\n{suggestion}\n```" if description else f"```suggestion\n{suggestion}\n```"
        
        # Get PR details for commit SHA
        pr_url = f"{self.base_url}/repos/{owner}/{repo}/pulls/{pr_number}"
        pr_response = requests.get(pr_url, headers=self.headers)
        
        if pr_response.status_code != 200:
            return None
            
        commit_sha = pr_response.json()["head"]["sha"]
        
        # Create review comment
        comment_url = f"{self.base_url}/repos/{owner}/{repo}/pulls/{pr_number}/comments"
        comment_data = {
            "body": body,
            "commit_id": commit_sha,
            "path": file_path,
            "position": position
        }
        
        response = requests.post(comment_url, headers=self.headers, 
                               json=comment_data)
        
        if response.status_code == 201:
            return response.json()
        else:
            print(f"Error: {response.status_code} - {response.text}")
            return None
    
    def list_suggestions(self, owner: str, repo: str, pr_number: int) -> List[Dict]:
        """List all suggestions in a PR."""
        
        comments_url = f"{self.base_url}/repos/{owner}/{repo}/pulls/{pr_number}/comments"
        response = requests.get(comments_url, headers=self.headers)
        
        if response.status_code != 200:
            return []
        
        # Filter comments that contain suggestion blocks
        suggestions = []
        for comment in response.json():
            if "```suggestion" in comment["body"]:
                suggestions.append(comment)
        
        return suggestions
    
    def delete_suggestion(self, owner: str, repo: str, comment_id: int) -> bool:
        """Delete a suggestion by deleting its comment."""
        
        delete_url = f"{self.base_url}/repos/{owner}/{repo}/pulls/comments/{comment_id}"
        response = requests.delete(delete_url, headers=self.headers)
        
        return response.status_code == 204

# Usage example
if __name__ == "__main__":
    api = GitHubSuggestionsAPI("your-token-here")
    
    # Create a suggestion
    result = api.create_suggestion(
        owner="octocat",
        repo="Hello-World", 
        pr_number=123,
        file_path="src/main.js",
        position=15,
        suggestion='const userName = "john";',
        description="Fix variable name"
    )
    
    if result:
        print(f"Suggestion created: {result['html_url']}")
    
    # List all suggestions
    suggestions = api.list_suggestions("octocat", "Hello-World", 123)
    print(f"Found {len(suggestions)} suggestions")
```

---

This API reference provides comprehensive technical documentation for implementing GitHub PR suggestions functionality. Use it alongside the practical guides and examples for complete implementation guidance.