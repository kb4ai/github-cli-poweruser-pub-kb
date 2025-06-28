# GitHub PR Review Comments - Usage Examples with Sample Data

## Overview

This document provides practical usage examples for GitHub PR review comments automation with real-world sample data and output formats.

## Sample Data Structure

### Sample PR Review Comment Response

```json
{
  "url": "https://api.github.com/repos/octocat/Hello-World/pulls/comments/1",
  "pull_request_review_id": 42,
  "id": 10,
  "node_id": "MDI0OlB1bGxSZXF1ZXN0UmV2aWV3Q29tbWVudDEw",
  "diff_hunk": "@@ -16,33 +16,40 @@ public class Connection : IConnection\n         if (this.State != ConnectionState.Open)\n             throw new InvalidOperationException(\"Not connected\");\n \n-        return this.DoSomething(request);\n+        if (request == null)\n+            throw new ArgumentNullException(nameof(request));\n+        \n+        return this.DoSomething(request);",
  "path": "src/Connection.cs",
  "position": 5,
  "original_position": 5,
  "commit_id": "6dcb09b5b57875f334f61aebed695e2e4193db5e",
  "original_commit_id": "9c48853fa3dc5c1c3d6f1f1cd1f2743e72652840",
  "in_reply_to_id": null,
  "user": {
    "login": "reviewer-alice",
    "id": 12345,
    "node_id": "MDQ6VXNlcjEyMzQ1",
    "avatar_url": "https://github.com/images/error/reviewer-alice_happy.gif",
    "gravatar_id": "",
    "url": "https://api.github.com/users/reviewer-alice",
    "type": "User",
    "site_admin": false
  },
  "body": "Great addition of null checking! This will prevent potential NullReferenceExceptions. Consider also adding unit tests to cover this edge case.",
  "created_at": "2023-12-15T14:30:25Z",
  "updated_at": "2023-12-15T14:30:25Z",
  "html_url": "https://github.com/octocat/Hello-World/pull/1#discussion-diff-1",
  "pull_request_url": "https://api.github.com/repos/octocat/Hello-World/pulls/1",
  "author_association": "COLLABORATOR",
  "start_line": null,
  "original_start_line": null,
  "start_side": null,
  "line": 19,
  "original_line": 16,
  "side": "RIGHT"
}
```

## Basic Usage Examples

### 1. Simple Comment Retrieval

```bash
# Get all review comments for PR #42
gh api repos/microsoft/vscode/pulls/42/comments
```

**Sample Output:**
```bash
$ ./basic-comment-reader.sh microsoft vscode 42

Fetching review comments for PR #42 in microsoft/vscode...
Found 8 review comment(s):

📍 src/vs/editor/common/model.ts:156
👤 reviewer-alice (COLLABORATOR)
💬 This method is doing too much. Consider breaking it into smaller, more focused methods for better maintainability.
📅 2023-12-15T09:15:32Z
🔗 https://github.com/microsoft/vscode/pull/42#discussion-diff-123456789
────────────────────────────────────────────────────────────────────────────────

📍 src/vs/editor/common/model.ts:203
👤 code-reviewer-bob (MEMBER)
💬 Good catch on the edge case! The null check here prevents a potential crash.
📅 2023-12-15T10:22:45Z
🔗 https://github.com/microsoft/vscode/pull/42#discussion-diff-123456790
────────────────────────────────────────────────────────────────────────────────

📍 src/vs/base/common/strings.ts:87
👤 security-team (MEMBER)
💬 Security concern: This string manipulation could be vulnerable to injection. Please sanitize input before processing.
📅 2023-12-15T11:30:12Z
🔗 https://github.com/microsoft/vscode/pull/42#discussion-diff-123456791
────────────────────────────────────────────────────────────────────────────────

Summary for PR #42:
  Review comments (inline): 8
  General comments: 3
  Total comments: 11
```

### 2. Filtered Comment Analysis

```bash
# Filter comments by specific user
./filtered-comment-reader.sh microsoft vscode 42 --user reviewer-alice --output json
```

**Sample Output:**
```json
[
  {
    "id": 123456789,
    "user": {
      "login": "reviewer-alice"
    },
    "body": "This method is doing too much. Consider breaking it into smaller, more focused methods for better maintainability.",
    "path": "src/vs/editor/common/model.ts",
    "line": 156,
    "created_at": "2023-12-15T09:15:32Z",
    "html_url": "https://github.com/microsoft/vscode/pull/42#discussion-diff-123456789"
  },
  {
    "id": 123456792,
    "user": {
      "login": "reviewer-alice"
    },
    "body": "LGTM! The refactoring looks clean and maintains backward compatibility.",
    "path": "src/vs/workbench/api/browser/mainThreadEditor.ts",
    "line": 245,
    "created_at": "2023-12-15T13:45:18Z",
    "html_url": "https://github.com/microsoft/vscode/pull/42#discussion-diff-123456792"
  }
]
```

### 3. Comments by File Path

```bash
# Get comments for specific file
./filtered-comment-reader.sh facebook react 1234 --file "packages/react/src/React.js"
```

**Sample Output:**
```bash
Filtering by file: packages/react/src/React.js
Found 4 comment(s) matching filters:

📍 File: packages/react/src/React.js:23
👤 User: dan-abramov (MEMBER)
💬 Comment: We should consider adding a deprecation warning here before the next major release.
📅 Created: 2023-12-14T16:20:33Z
🔗 URL: https://github.com/facebook/react/pull/1234#discussion-diff-987654321
────────────────────────────────────────────────────────────────────────────────

📍 File: packages/react/src/React.js:87
👤 User: gaearon (MEMBER)
💬 Comment: This optimization looks good, but let's make sure we have comprehensive tests covering all edge cases.
📅 Created: 2023-12-14T17:33:12Z
🔗 URL: https://github.com/facebook/react/pull/1234#discussion-diff-987654322
────────────────────────────────────────────────────────────────────────────────
```

## Advanced Filtering Examples

### 4. Time-based Filtering

```bash
# Comments from last 24 hours
./filtered-comment-reader.sh golang go 5678 --days 1 --output csv
```

**Sample CSV Output:**
```csv
user,file,line,body,created_at,html_url,reply_to_id
robpike,src/cmd/compile/internal/gc/main.go,142,"This could benefit from better error messages for debugging",2023-12-15T08:30:15Z,https://github.com/golang/go/pull/5678#discussion-diff-555666777,
ianletham,src/runtime/proc.go,891,"Performance improvement looks solid. Did you run the benchmarks?",2023-12-15T10:15:42Z,https://github.com/golang/go/pull/5678#discussion-diff-555666778,
bradfitz,src/net/http/server.go,456,"LGTM but please add a comment explaining the magic number",2023-12-15T12:22:18Z,https://github.com/golang/go/pull/5678#discussion-diff-555666779,
```

### 5. Text Pattern Matching

```bash
# Find all "LGTM" comments
./filtered-comment-reader.sh torvalds linux 9999 --text "LGTM|looks good|approved" --output json | jq length
```

**Sample Output:**
```bash
Filtering by text: LGTM|looks good|approved
Found 12 comment(s) matching filters:
12
```

## Export Examples

### 6. Markdown Export

```bash
./comment-exporter.sh kubernetes kubernetes 3456 pr-review-report.md markdown
```

**Sample Markdown Output:**
```markdown
# PR Review Comments Export

**Repository:** kubernetes/kubernetes  
**PR #:** 3456  
**Title:** Add support for custom resource validation  
**Author:** contributor-jane  
**Created:** 2023-12-10T14:22:15Z  
**URL:** https://github.com/kubernetes/kubernetes/pull/3456  
**Exported:** 2023-12-15T15:30:00Z  

## Summary

- Review Comments (inline): 15
- General Comments: 8
- Total Comments: 23

## Review Comments (Inline)

### Comment by @sig-api-machinery-lead

**File:** `staging/src/k8s.io/apiextensions-apiserver/pkg/apis/apiextensions/validation/validation.go`  
**Line:** 234  
**Created:** 2023-12-12T09:15:45Z  
**URL:** https://github.com/kubernetes/kubernetes/pull/3456#discussion-diff-111222333  

This validation logic looks comprehensive. Have you considered the performance impact on large CRDs with complex schemas?

We should benchmark this against the existing validation to ensure we're not introducing significant latency.

---

### Comment by @contributor-bob

**File:** `staging/src/k8s.io/apiextensions-apiserver/pkg/apis/apiextensions/validation/validation.go`  
**Line:** 267  
**Created:** 2023-12-12T11:30:22Z  
**URL:** https://github.com/kubernetes/kubernetes/pull/3456#discussion-diff-111222334  
**Reply to:** 111222333  

Good point about performance. I ran some benchmarks and the impact is minimal (<5% overhead) for typical use cases. I'll add the benchmark results to the PR description.

---
```

### 7. HTML Export with Styling

```bash
./comment-exporter.sh apache kafka 2345 kafka-pr-review.html html
```

**Sample HTML Output Preview:**
- Professional styling with GitHub-like appearance
- Color-coded comment types (review vs general)
- Clickable links to original GitHub comments
- Responsive design for mobile viewing
- Threaded reply visualization

### 8. JSON Export for Data Analysis

```bash
./comment-exporter.sh nodejs node 7890 node-comments.json json
```

**Sample JSON Structure:**
```json
{
  "metadata": {
    "exported_at": "2023-12-15T15:45:30Z",
    "repository": "nodejs/node",
    "pr_number": 7890,
    "pr_title": "stream: improve performance of readable streams",
    "pr_author": "nodejs-contributor",
    "pr_created_at": "2023-12-12T10:30:15Z",
    "pr_url": "https://github.com/nodejs/node/pull/7890",
    "total_review_comments": 18,
    "total_issue_comments": 6
  },
  "review_comments": [
    {
      "id": 999888777,
      "user": {
        "login": "addaleax",
        "type": "User"
      },
      "body": "This optimization is impressive! The benchmark results show significant improvement. One suggestion: could we add a feature flag to allow users to opt out if they encounter issues?",
      "path": "lib/internal/streams/readable.js",
      "line": 123,
      "created_at": "2023-12-13T14:20:18Z",
      "in_reply_to_id": null,
      "author_association": "MEMBER"
    }
  ],
  "issue_comments": [
    {
      "id": 888777666,
      "user": {
        "login": "nodejs-contributor"
      },
      "body": "Thanks for all the feedback! I've addressed the performance concerns and added comprehensive tests. Ready for another review.",
      "created_at": "2023-12-14T09:15:30Z",
      "author_association": "CONTRIBUTOR"
    }
  ]
}
```

## Batch Analysis Examples

### 9. Repository-wide Analysis

```bash
./batch-pr-analyzer.sh microsoft typescript --state open --days 30 --detailed --output typescript-analysis.json
```

**Sample Console Output:**
```bash
Analyzing PR review comments for microsoft/typescript...
Filtering by last 30 days
Found 25 PR(s) to analyze

Analyzing PR #12345: Add support for import assertions
  Author: typescript-contributor, Created: 2023-11-20T14:30:15Z
  Review comments: 12, General comments: 4, Total: 16
  Detailed comment analysis:
  Top commenters:
    RyanCavanaugh: 4 comments
    DanielRosenwasser: 3 comments
    sandersn: 2 comments
  Most commented files:
    src/compiler/checker.ts: 5 comments
    src/compiler/parser.ts: 3 comments
    src/compiler/binder.ts: 2 comments

Analyzing PR #12346: Improve error messages for template literal types
  Author: another-contributor, Created: 2023-11-22T09:45:22Z
  Review comments: 8, General comments: 2, Total: 10
  ...

Analysis Summary:
  Repository: microsoft/typescript
  PRs analyzed: 25
  Total review comments: 287
  Total general comments: 89
  Total comments: 376
  Average review comments per PR: 11
  Average general comments per PR: 3
  Average total comments per PR: 15
```

### 10. Team Performance Metrics

```bash
# Analyze team activity over last quarter
./batch-pr-analyzer.sh facebook react --days 90 --max-prs 100 --output react-team-metrics.json

# Extract insights
jq '.analysis.prs | group_by(.pr_info.author) | map({author: .[0].pr_info.author, prs: length, avg_comments: (map(.comment_stats.total_comments) | add / length)})' react-team-metrics.json
```

**Sample Analytics Output:**
```json
[
  {
    "author": "gaearon",
    "prs": 8,
    "avg_comments": 12.5
  },
  {
    "author": "sebmarkbage",
    "prs": 6,
    "avg_comments": 18.3
  },
  {
    "author": "acdlite",
    "prs": 12,
    "avg_comments": 9.2
  }
]
```

## Real-world Integration Examples

### 11. CI/CD Integration

```bash
#!/bin/bash
# ci-review-check.sh - Ensure PR has adequate review coverage

OWNER="$1"
REPO="$2"
PR_NUMBER="$3"
MIN_REVIEWERS=2

# Get review comments
comments=$(gh api repos/"$OWNER"/"$REPO"/pulls/"$PR_NUMBER"/comments)
unique_reviewers=$(echo "$comments" | jq -r '.[].user.login' | sort -u | wc -l)

if [ "$unique_reviewers" -lt "$MIN_REVIEWERS" ]; then
    echo "❌ PR needs at least $MIN_REVIEWERS reviewers (found: $unique_reviewers)"
    exit 1
else
    echo "✅ PR has adequate review coverage ($unique_reviewers reviewers)"
fi
```

### 12. Automated Quality Checks

```bash
#!/bin/bash
# quality-gate.sh - Check for specific review patterns

OWNER="$1"
REPO="$2"
PR_NUMBER="$3"

comments=$(gh api repos/"$OWNER"/"$REPO"/pulls/"$PR_NUMBER"/comments)

# Check for security review
security_comments=$(echo "$comments" | jq '[.[] | select(.body | test("security|vulnerability|CVE"; "i"))] | length')

# Check for performance review  
perf_comments=$(echo "$comments" | jq '[.[] | select(.body | test("performance|benchmark|optimization"; "i"))] | length')

# Check for test coverage review
test_comments=$(echo "$comments" | jq '[.[] | select(.body | test("test|coverage|spec"; "i"))] | length')

echo "Review Quality Summary:"
echo "  Security reviews: $security_comments"
echo "  Performance reviews: $perf_comments"
echo "  Test coverage reviews: $test_comments"

# Quality gate logic
if [ "$security_comments" -eq 0 ] && echo "$comments" | jq -e '.[] | select(.path | test("auth|security|crypto"))' >/dev/null; then
    echo "⚠️  Security-related files changed but no security review found"
fi
```

### 13. Slack Integration with Rich Formatting

```bash
#!/bin/bash
# slack-pr-summary.sh - Send formatted PR review summary to Slack

SLACK_WEBHOOK="$1"
OWNER="$2"
REPO="$3"
PR_NUMBER="$4"

# Get PR info and comments
pr_info=$(gh api repos/"$OWNER"/"$REPO"/pulls/"$PR_NUMBER")
comments=$(gh api repos/"$OWNER"/"$REPO"/pulls/"$PR_NUMBER"/comments)

pr_title=$(echo "$pr_info" | jq -r '.title')
pr_author=$(echo "$pr_info" | jq -r '.user.login')
pr_url=$(echo "$pr_info" | jq -r '.html_url')

comment_count=$(echo "$comments" | jq '. | length')
reviewer_count=$(echo "$comments" | jq -r '.[].user.login' | sort -u | wc -l)

# Create rich Slack message
slack_payload=$(cat <<EOF
{
  "blocks": [
    {
      "type": "header",
      "text": {
        "type": "plain_text",
        "text": "PR Review Summary 📊"
      }
    },
    {
      "type": "section",
      "fields": [
        {
          "type": "mrkdwn",
          "text": "*Repository:* $OWNER/$REPO"
        },
        {
          "type": "mrkdwn",
          "text": "*PR #:* <$pr_url|$PR_NUMBER>"
        },
        {
          "type": "mrkdwn",
          "text": "*Title:* $pr_title"
        },
        {
          "type": "mrkdwn",
          "text": "*Author:* $pr_author"
        },
        {
          "type": "mrkdwn",
          "text": "*Comments:* $comment_count"
        },
        {
          "type": "mrkdwn",
          "text": "*Reviewers:* $reviewer_count"
        }
      ]
    }
  ]
}
EOF
)

curl -X POST -H 'Content-type: application/json' \
  --data "$slack_payload" \
  "$SLACK_WEBHOOK"
```

## Performance Optimization Examples

### 14. Efficient Large-scale Analysis

```bash
#!/bin/bash
# efficient-batch-analysis.sh - Optimized for large repositories

OWNER="$1"
REPO="$2"
OUTPUT_DIR="analysis-$(date +%Y%m%d)"

mkdir -p "$OUTPUT_DIR"

# Get PR list efficiently
gh api "repos/$OWNER/$REPO/pulls?state=all&per_page=100" > "$OUTPUT_DIR/prs.json"

# Process in parallel batches
jq -r '.[].number' "$OUTPUT_DIR/prs.json" | head -20 | xargs -P 5 -I {} bash -c '
  echo "Processing PR #{}"
  gh api "repos/'$OWNER'/'$REPO'/pulls/{}/comments" > "'$OUTPUT_DIR'/pr-{}-comments.json"
'

# Aggregate results
jq -s 'add' "$OUTPUT_DIR"/pr-*-comments.json > "$OUTPUT_DIR/all-comments.json"

echo "Analysis complete. Results in $OUTPUT_DIR/"
```

### 15. Caching for Repeated Analysis

```bash
#!/bin/bash
# cached-analysis.sh - Use caching to avoid repeated API calls

CACHE_DIR=".comment-cache"
CACHE_TTL=3600  # 1 hour

get_cached_or_fetch() {
    local cache_file="$CACHE_DIR/$1-$2-$3.json"
    
    if [ -f "$cache_file" ] && [ $(($(date +%s) - $(stat -c %Y "$cache_file"))) -lt $CACHE_TTL ]; then
        cat "$cache_file"
    else
        mkdir -p "$CACHE_DIR"
        gh api "repos/$1/$2/pulls/$3/comments" | tee "$cache_file"
    fi
}

# Usage
comments=$(get_cached_or_fetch "microsoft" "vscode" "12345")
echo "$comments" | jq '. | length'
```

This comprehensive set of examples demonstrates practical usage patterns for GitHub PR review comment automation, from basic retrieval to advanced analytics and integrations.