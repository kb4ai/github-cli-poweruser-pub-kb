# GitHub PR Suggestions - Comprehensive Guide

This guide provides complete documentation for GitHub Pull Request suggested changes functionality, including API usage, syntax reference, and automation tools.

## Table of Contents

- [Overview](#overview)
- [Suggestion Syntax](#suggestion-syntax)  
- [API Endpoints](#api-endpoints)
- [Script Usage](#script-usage)
- [Advanced Features](#advanced-features)
- [Best Practices](#best-practices)
- [Limitations](#limitations)
- [Troubleshooting](#troubleshooting)

## Overview

GitHub's suggested changes feature allows reviewers to propose specific code modifications that can be accepted with a single click. This powerful collaboration tool streamlines the code review process by enabling precise, actionable feedback.

### Key Features

- **Single-line suggestions**: Propose changes to individual lines
- **Multi-line suggestions**: Suggest modifications spanning multiple lines
- **One-click acceptance**: Authors can apply suggestions instantly
- **Co-authorship credit**: Suggestion authors receive commit co-authorship
- **Batch operations**: Apply multiple suggestions simultaneously

### How It Works

1. **Reviewer creates suggestion**: Using special markdown syntax in review comments
2. **Author reviews suggestion**: Sees proposed changes in GitHub UI
3. **Author accepts/rejects**: Can apply changes with one click or dismiss
4. **Automatic commit**: Accepted suggestions create commits with co-authorship

## Suggestion Syntax

### Basic Syntax

Suggestions use fenced code blocks with the `suggestion` language identifier:

```markdown
Optional description of the change

```suggestion
proposed code here
```
```

### Single-Line Suggestions

For single-line changes:

```markdown
Fix typo in variable name

```suggestion
const userName = 'john';
```
```

### Multi-Line Suggestions

For changes spanning multiple lines:

```markdown
Improve error handling

```suggestion
try {
  const result = await apiCall();
  return result;
} catch (error) {
  console.error('API call failed:', error);
  throw new Error('Failed to fetch data');
}
```
```

### Syntax Rules

1. **Fenced blocks**: Use three backticks with `suggestion` language
2. **Content matching**: Suggested content replaces the selected lines exactly
3. **Line boundaries**: Suggestions apply to complete lines only
4. **Whitespace preservation**: Indentation and spacing must match exactly
5. **No nested suggestions**: Cannot include suggestion blocks within suggestions

### Special Characters

When suggesting changes that include backticks or other markdown syntax:

```markdown
Fix code block formatting

```suggestion
console.log(`Hello ${name}!`);
```
```

## API Endpoints

### REST API Endpoints

#### Create Review Comment with Suggestion

```bash
POST /repos/{owner}/{repo}/pulls/{pull_number}/comments
```

**Request Body:**
```json
{
  "body": "Fix the variable name\n\n```suggestion\nconst userName = 'john';\n```",
  "commit_id": "sha",
  "path": "src/main.js",
  "position": 15
}
```

#### Create Review with Suggestions

```bash
POST /repos/{owner}/{repo}/pulls/{pull_number}/reviews
```

**Request Body:**
```json
{
  "commit_id": "sha",
  "body": "Review with suggestions",
  "event": "COMMENT",
  "comments": [
    {
      "path": "src/main.js",
      "position": 15,
      "body": "```suggestion\nconst userName = 'john';\n```"
    }
  ]
}
```

#### List Review Comments

```bash
GET /repos/{owner}/{repo}/pulls/{pull_number}/comments
```

Filter for suggestions:
```bash
# Comments containing suggestion blocks
jq '.[] | select(.body | test("```suggestion"))'
```

#### Delete Suggestion

```bash
DELETE /repos/{owner}/{repo}/pulls/comments/{comment_id}
```

### GraphQL API

Currently, there are no specific GraphQL mutations for suggestions. Use the existing review comment mutations:

```graphql
mutation AddPullRequestReviewComment($pullRequestId: ID!, $body: String!, $path: String!, $position: Int!) {
  addPullRequestReviewComment(input: {
    pullRequestId: $pullRequestId
    body: $body
    path: $path
    position: $position
  }) {
    comment {
      id
      body
      url
    }
  }
}
```

## Script Usage

### create-suggestion.sh

Create individual suggestions programmatically.

**Basic Usage:**
```bash
./create-suggestion.sh OWNER REPO PR_NUMBER FILE_PATH LINE_NUMBER SUGGESTION_TEXT [DESCRIPTION]
```

**Examples:**

Single-line suggestion:
```bash
./create-suggestion.sh octocat Hello-World 123 "src/main.js" 45 \
  "console.log('fixed');" "Fix console message"
```

Multi-line suggestion:
```bash
./create-suggestion.sh octocat Hello-World 123 "README.md" 10 \
  "# New Title\nThis is better content" "Improve documentation"
```

**Features:**
- Validates PR and repository existence
- Supports both single and multi-line suggestions
- Provides detailed error messages
- Handles authentication automatically

### manage-suggestions.sh

Comprehensive CRUD operations for suggestions.

**Commands:**
- `list` - List all suggestions in a PR
- `show` - Show specific suggestion details  
- `delete` - Delete a suggestion
- `analyze` - Analyze suggestions in a PR
- `export` - Export suggestions to various formats
- `stats` - Show suggestion statistics

**Examples:**

List all suggestions:
```bash
./manage-suggestions.sh list octocat Hello-World 123
```

Show specific suggestion:
```bash
./manage-suggestions.sh show octocat Hello-World 123 --comment-id 456789
```

Export to JSON:
```bash
./manage-suggestions.sh export octocat Hello-World 123 --format json --file suggestions.json
```

Delete suggestion:
```bash
./manage-suggestions.sh delete octocat Hello-World 123 --comment-id 456789
```

### suggestion-analyzer.sh

Advanced analysis and reporting capabilities.

**Commands:**
- `pr-analysis` - Analyze specific PR
- `repo-analysis` - Repository-wide analysis
- `user-analysis` - User pattern analysis
- `export-report` - Generate comprehensive reports

**Examples:**

Analyze specific PR:
```bash
./suggestion-analyzer.sh pr-analysis octocat Hello-World --pr 123
```

Repository analysis:
```bash
./suggestion-analyzer.sh repo-analysis octocat Hello-World --days 30 --limit 50
```

User pattern analysis:
```bash
./suggestion-analyzer.sh user-analysis octocat Hello-World --user johndoe --days 90
```

Generate HTML report:
```bash
./suggestion-analyzer.sh export-report octocat Hello-World --format html --output report.html
```

## Advanced Features

### Batch Suggestion Creation

Create multiple suggestions efficiently:

```bash
#!/bin/bash
# Batch create suggestions from file

while IFS=',' read -r file line suggestion description; do
  ./create-suggestion.sh "$OWNER" "$REPO" "$PR" "$file" "$line" "$suggestion" "$description"
  sleep 1  # Rate limiting
done < suggestions.csv
```

### Suggestion Templates

Common suggestion patterns:

**Console.log removal:**
```bash
SUGGESTION="// Remove debug log"
./create-suggestion.sh "$OWNER" "$REPO" "$PR" "$FILE" "$LINE" "$SUGGESTION" "Remove debug statement"
```

**Import optimization:**
```bash
SUGGESTION="import { specific, functions } from 'module';"
./create-suggestion.sh "$OWNER" "$REPO" "$PR" "$FILE" "$LINE" "$SUGGESTION" "Use specific imports"
```

### Integration with CI/CD

Automated suggestion generation:

```yaml
# GitHub Actions example
name: Auto Suggestions
on:
  pull_request:
    types: [opened, synchronize]

jobs:
  suggest:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Generate suggestions
        run: |
          # Run linting and generate suggestions
          ./scripts/auto-suggest.sh ${{ github.event.pull_request.number }}
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Custom Analysis Scripts

Create domain-specific analyzers:

```bash
#!/bin/bash
# analyze-security-suggestions.sh

# Find security-related suggestions
./manage-suggestions.sh list "$OWNER" "$REPO" "$PR" --output json | \
jq '.[] | select(.description | test("security|vulnerability|auth"; "i"))'
```

## Best Practices

### For Reviewers

1. **Be Specific**: Provide clear, actionable suggestions
2. **Add Context**: Include descriptions explaining the "why"
3. **Small Changes**: Keep suggestions focused and minimal
4. **Test Locally**: Verify suggestions work before submitting
5. **Respect Style**: Follow project coding standards

**Good Example:**
```markdown
Use const instead of let for immutable values

```suggestion
const API_URL = 'https://api.example.com';
```
```

**Poor Example:**
```markdown
```suggestion
const API_URL = 'https://api.example.com';
```
```

### For Authors

1. **Review Carefully**: Check suggestions thoroughly before accepting
2. **Test Changes**: Verify suggestions don't break functionality
3. **Batch Accept**: Apply related suggestions together
4. **Acknowledge Contributors**: Thank reviewers for helpful suggestions
5. **Learn Patterns**: Use suggestions to improve coding practices

### For Teams

1. **Establish Guidelines**: Define when to use suggestions vs. regular comments
2. **Encourage Adoption**: Train team members on suggestion features
3. **Monitor Metrics**: Track suggestion usage and acceptance rates
4. **Automate Where Possible**: Use scripts for common suggestion patterns
5. **Document Patterns**: Create templates for frequent suggestion types

## Limitations

### Technical Limitations

1. **No Programmatic Acceptance**: Cannot accept suggestions via API
2. **Line-Based Only**: Cannot suggest partial line changes
3. **Diff Context Required**: Must target lines visible in PR diff
4. **No Suggestion Updates**: Cannot modify suggestions after creation
5. **Rate Limiting**: API calls are subject to GitHub rate limits

### Functional Limitations

1. **UI-Only Acceptance**: Authors must use GitHub web interface
2. **No Batch API**: No bulk suggestion operations via API
3. **Limited Metadata**: Cannot track acceptance/rejection programmatically
4. **File Scope**: Suggestions limited to files changed in PR
5. **Position Calculation**: Complex diff position calculations required

### Workarounds

**Position Calculation:**
```bash
# Use gh cli with diff format
gh api repos/$OWNER/$REPO/pulls/$PR -H "Accept: application/vnd.github.v3.diff" | \
  grep -n "^+" | head -5
```

**Acceptance Tracking:**
```bash
# Monitor commit messages for suggestion acceptance
git log --grep="Co-authored-by" --oneline
```

## Troubleshooting

### Common Issues

#### "Position not found in diff"

**Problem**: Suggestion targets line not in PR diff

**Solution:**
```bash
# Get actual diff positions
gh pr diff $PR_NUMBER | grep -n "your-code-line"
```

#### "Invalid suggestion syntax"

**Problem**: Malformed suggestion blocks

**Solution:**
```bash
# Validate suggestion format
echo "$SUGGESTION_TEXT" | grep -E '^```suggestion$|^```$'
```

#### "Comment creation failed"

**Problem**: Authentication or permission issues

**Solution:**
```bash
# Check authentication
gh auth status

# Verify repository access
gh api repos/$OWNER/$REPO
```

### Debug Mode

Enable verbose logging:

```bash
export DEBUG=1
./create-suggestion.sh args...
```

Check API responses:
```bash
gh api repos/$OWNER/$REPO/pulls/$PR/comments --verbose
```

### Rate Limiting

Handle rate limits gracefully:

```bash
#!/bin/bash
check_rate_limit() {
  local remaining=$(gh api rate_limit --jq '.rate.remaining')
  if [ "$remaining" -lt 10 ]; then
    echo "Rate limit low, waiting..."
    sleep 60
  fi
}
```

### Error Recovery

Implement retry logic:

```bash
retry_api_call() {
  local retries=3
  local count=0
  
  while [ $count -lt $retries ]; do
    if gh api "$@"; then
      return 0
    fi
    count=$((count + 1))
    echo "Retry $count/$retries..."
    sleep $((count * 2))
  done
  
  return 1
}
```

## Security Considerations

### Token Permissions

Required scopes for suggestions:
- `repo` - Full repository access
- `public_repo` - Public repository access (for public repos only)

### Input Validation

Always validate user inputs:

```bash
validate_pr_number() {
  if [[ ! "$1" =~ ^[0-9]+$ ]]; then
    echo "Error: Invalid PR number"
    exit 1
  fi
}
```

### Rate Limiting

Respect API limits:
- REST API: 5,000 requests per hour (authenticated)
- GraphQL API: 5,000 points per hour
- Secondary rate limits: Avoid rapid-fire requests

### Safe Scripting

Use safe bash practices:
```bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures
```

## Performance Optimization

### Caching

Cache API responses:
```bash
CACHE_DIR="/tmp/gh-cache"
mkdir -p "$CACHE_DIR"

cached_api_call() {
  local endpoint="$1"
  local cache_file="$CACHE_DIR/$(echo "$endpoint" | tr '/' '_')"
  
  if [ -f "$cache_file" ] && [ $(($(date +%s) - $(stat -c %Y "$cache_file"))) -lt 300 ]; then
    cat "$cache_file"
  else
    gh api "$endpoint" | tee "$cache_file"
  fi
}
```

### Parallel Processing

Process multiple PRs concurrently:
```bash
process_pr() {
  local pr="$1"
  ./manage-suggestions.sh analyze "$OWNER" "$REPO" "$pr" &
}

# Process up to 5 PRs in parallel
for pr in "${prs[@]}"; do
  (($(jobs -r | wc -l) >= 5)) && wait
  process_pr "$pr"
done
wait
```

## Contributing

### Development Setup

1. Clone the repository
2. Install dependencies: `gh`, `jq`, `bash`
3. Run tests: `./test-safety-fixes.sh`
4. Submit pull requests with suggestions!

### Testing

Test against the development repository:
```bash
export TEST_OWNER="gwwtests"
export TEST_REPO="testxxxyyzzzzz"
export TEST_PR="1"

./create-suggestion.sh "$TEST_OWNER" "$TEST_REPO" "$TEST_PR" \
  "README.md" 1 "# Test Repository" "Update title"
```

---

This comprehensive guide covers all aspects of GitHub PR suggestions functionality. For additional examples and use cases, see [github-pr-suggestions-examples.md](./github-pr-suggestions-examples.md).