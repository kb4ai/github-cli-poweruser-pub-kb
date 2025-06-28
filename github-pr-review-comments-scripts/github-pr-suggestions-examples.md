# GitHub PR Suggestions - Practical Examples

This document provides real-world examples and practical workflows for using GitHub Pull Request suggested changes functionality.

## Table of Contents

- [Basic Usage Examples](#basic-usage-examples)
- [Advanced Workflows](#advanced-workflows)
- [Automation Scenarios](#automation-scenarios)
- [Team Collaboration Patterns](#team-collaboration-patterns)
- [Integration Examples](#integration-examples)
- [Troubleshooting Scenarios](#troubleshooting-scenarios)

## Basic Usage Examples

### Single-Line Suggestions

#### Example 1: Fix Typo
```bash
./create-suggestion.sh octocat Hello-World 123 "README.md" 5 \
  "# Hello, World!" "Fix typo in title"
```

**Original Line:**
```markdown
# Hello, Wrold!
```

**Suggested Change:**
```markdown
# Hello, World!
```

#### Example 2: Variable Naming
```bash
./create-suggestion.sh myorg myproject 456 "src/utils.js" 12 \
  "const userData = await fetchUser(id);" "Use descriptive variable name"
```

**Original Line:**
```javascript
const data = await fetchUser(id);
```

**Suggested Change:**
```javascript
const userData = await fetchUser(id);
```

### Multi-Line Suggestions

#### Example 3: Function Improvement
```bash
./create-suggestion.sh myorg myproject 456 "src/auth.js" 25 \
  "async function validateUser(token) {
  if (!token) {
    throw new Error('Token is required');
  }
  
  try {
    const user = await verifyToken(token);
    return user;
  } catch (error) {
    throw new Error('Invalid token');
  }
}" "Add proper error handling and validation"
```

**Original Code:**
```javascript
function validateUser(token) {
  return verifyToken(token);
}
```

**Suggested Change:**
```javascript
async function validateUser(token) {
  if (!token) {
    throw new Error('Token is required');
  }
  
  try {
    const user = await verifyToken(token);
    return user;
  } catch (error) {
    throw new Error('Invalid token');
  }
}
```

## Advanced Workflows

### Batch Suggestion Creation

#### Scenario: Code Review Cleanup

Create a CSV file with multiple suggestions:
```csv
src/main.js,45,console.log('Debug info');,Remove debug statement
src/utils.js,12,const userData = response.data;,Use destructuring
src/config.js,8,const API_URL = 'http://localhost:3000';,Use environment variable
```

Batch processing script:
```bash
#!/bin/bash
# batch-suggestions.sh

OWNER="$1"
REPO="$2"
PR_NUMBER="$3"
SUGGESTIONS_FILE="$4"

echo "Creating batch suggestions for PR #$PR_NUMBER..."

while IFS=',' read -r file line suggestion description; do
  echo "Creating suggestion for $file:$line"
  ./create-suggestion.sh "$OWNER" "$REPO" "$PR_NUMBER" "$file" "$line" "$suggestion" "$description"
  
  # Rate limiting
  sleep 2
done < "$SUGGESTIONS_FILE"

echo "Batch suggestions completed!"
```

Usage:
```bash
./batch-suggestions.sh myorg myproject 123 suggestions.csv
```

### Multi-File Refactoring

#### Scenario: Import Statement Cleanup

```bash
#!/bin/bash
# cleanup-imports.sh

OWNER="myorg"
REPO="myproject"
PR_NUMBER="456"

# Find all JavaScript files with problematic imports
files=$(gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/files" --jq '.[].filename | select(endswith(".js"))')

for file in $files; do
  echo "Processing $file..."
  
  # Check for default imports that should be named imports
  if grep -q "import React from 'react'" "$file"; then
    line_number=$(grep -n "import React from 'react'" "$file" | cut -d: -f1)
    ./create-suggestion.sh "$OWNER" "$REPO" "$PR_NUMBER" "$file" "$line_number" \
      "import { React } from 'react';" "Use named import for React"
  fi
  
  # Check for unused imports
  if grep -q "import { useState }" "$file" && ! grep -q "useState" "$file"; then
    line_number=$(grep -n "import.*useState" "$file" | cut -d: -f1)
    ./create-suggestion.sh "$OWNER" "$REPO" "$PR_NUMBER" "$file" "$line_number" \
      "// Removed unused useState import" "Remove unused import"
  fi
done
```

### Conditional Suggestions

#### Scenario: Security Improvements

```bash
#!/bin/bash
# security-suggestions.sh

OWNER="$1"
REPO="$2"
PR_NUMBER="$3"

# Get all files in the PR
files=$(gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/files" --jq '.[].filename')

for file in $files; do
  echo "Scanning $file for security issues..."
  
  # Check for hardcoded passwords
  if grep -n "password.*=" "$file" | grep -E "(123|admin|secret)"; then
    while IFS=':' read -r line_number content; do
      ./create-suggestion.sh "$OWNER" "$REPO" "$PR_NUMBER" "$file" "$line_number" \
        "// TODO: Use environment variable for password" \
        "Security: Avoid hardcoded passwords"
    done < <(grep -n "password.*=" "$file" | grep -E "(123|admin|secret)")
  fi
  
  # Check for SQL injection risks
  if grep -n "SELECT.*+.*" "$file"; then
    while IFS=':' read -r line_number content; do
      ./create-suggestion.sh "$OWNER" "$REPO" "$PR_NUMBER" "$file" "$line_number" \
        "// Use parameterized queries instead of string concatenation" \
        "Security: Prevent SQL injection"
    done < <(grep -n "SELECT.*+.*" "$file")
  fi
done
```

## Automation Scenarios

### CI/CD Integration

#### GitHub Actions Workflow

```yaml
# .github/workflows/auto-suggestions.yml
name: Auto Suggestions

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  create-suggestions:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
        with:
          fetch-depth: 0
      
      - name: Setup GitHub CLI
        run: |
          gh auth login --with-token <<< "${{ secrets.GITHUB_TOKEN }}"
      
      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y jq
      
      - name: Run linting and create suggestions
        run: |
          # Get PR number
          PR_NUMBER="${{ github.event.pull_request.number }}"
          
          # Run eslint and create suggestions for each issue
          npm run lint:json > lint-results.json || true
          
          # Process lint results and create suggestions
          jq -r '.[] | .messages[] | select(.severity == 2) | "\(.line),\(.message),\(.ruleId)"' lint-results.json | \
          while IFS=',' read -r line message rule; do
            if [ "$rule" = "no-console" ]; then
              ./create-suggestion.sh "${{ github.repository_owner }}" "${{ github.event.repository.name }}" \
                "$PR_NUMBER" "$file" "$line" "// Remove console.log" "ESLint: $message"
            fi
          done
        
      - name: Create style suggestions
        run: |
          # Run prettier and create formatting suggestions
          npx prettier --check . --write || true
          
          # Check for changes and create suggestions
          git diff --name-only | while read -r file; do
            if [[ "$file" =~ \.(js|ts|jsx|tsx)$ ]]; then
              ./create-suggestion.sh "${{ github.repository_owner }}" "${{ github.event.repository.name }}" \
                "${{ github.event.pull_request.number }}" "$file" "1" \
                "$(cat "$file")" "Auto-format with Prettier"
            fi
          done
```

### Pre-commit Hook Integration

#### Setup Pre-commit Suggestions

```bash
#!/bin/bash
# .git/hooks/pre-push

# Check if pushing to a PR branch
current_branch=$(git rev-parse --abbrev-ref HEAD)
if [[ "$current_branch" == "feature/"* ]] || [[ "$current_branch" == "fix/"* ]]; then
  echo "Running pre-push suggestion checks..."
  
  # Find associated PR
  pr_number=$(gh pr list --head "$current_branch" --json number --jq '.[0].number')
  
  if [ -n "$pr_number" ]; then
    echo "Found PR #$pr_number for branch $current_branch"
    
    # Run automated suggestions
    ./scripts/auto-suggest.sh "$pr_number"
  fi
fi
```

### Scheduled Analysis

#### Weekly Suggestion Reports

```bash
#!/bin/bash
# weekly-suggestion-report.sh

OWNER="myorg"
REPO="myproject"

# Get date range for last week
end_date=$(date +%Y-%m-%d)
start_date=$(date -d "7 days ago" +%Y-%m-%d)

echo "Generating suggestion report for $start_date to $end_date"

# Get all PRs from last week
prs=$(gh pr list --state all --limit 50 --json number,createdAt \
  --jq --arg start "$start_date" --arg end "$end_date" \
  '.[] | select(.createdAt >= $start and .createdAt <= $end) | .number')

# Analyze each PR
for pr in $prs; do
  echo "Analyzing PR #$pr..."
  ./suggestion-analyzer.sh pr-analysis "$OWNER" "$REPO" --pr "$pr" --format json >> weekly-analysis.json
done

# Generate summary report
jq -s '{
  period: "'$start_date' to '$end_date'",
  total_prs: length,
  total_suggestions: [.[].analysis.total_suggestions] | add,
  avg_suggestions_per_pr: ([.[].analysis.total_suggestions] | add / length),
  top_contributors: [.[].analysis.contributors[]?] | group_by(.user) | map({user: .[0].user, total: [.[].count] | add}) | sort_by(-.total)[:5]
}' weekly-analysis.json > weekly-summary.json

echo "Report generated: weekly-summary.json"
```

## Team Collaboration Patterns

### Code Review Guidelines

#### Suggestion Priority System

```bash
#!/bin/bash
# prioritize-suggestions.sh

OWNER="$1"
REPO="$2"
PR_NUMBER="$3"

# Get all suggestions
suggestions=$(./manage-suggestions.sh list "$OWNER" "$REPO" "$PR_NUMBER" --output json)

# Categorize by priority
echo "$suggestions" | jq '
  group_by(
    if (.description | test("security|vulnerability"; "i")) then "🔴 Critical"
    elif (.description | test("bug|error|fix"; "i")) then "🟡 High"
    elif (.description | test("style|format|lint"; "i")) then "🔵 Medium"
    else "⚪ Low"
    end
  ) | 
  map({
    priority: .[0].priority // "Unknown",
    count: length,
    suggestions: .
  })'
```

#### Team Review Workflow

```bash
#!/bin/bash
# team-review-workflow.sh

PR_NUMBER="$1"
OWNER="myorg"
REPO="myproject"

echo "🔍 Starting team review workflow for PR #$PR_NUMBER"

# Step 1: Automated suggestions
echo "Step 1: Creating automated suggestions..."
./scripts/auto-lint-suggestions.sh "$PR_NUMBER"
./scripts/auto-security-suggestions.sh "$PR_NUMBER"

# Step 2: Assign reviewers based on files changed
echo "Step 2: Assigning reviewers..."
files=$(gh pr view "$PR_NUMBER" --json files --jq '.files[].path')

reviewers=()
for file in $files; do
  case "$file" in
    "src/auth/"*) reviewers+=("security-team") ;;
    "src/api/"*) reviewers+=("backend-team") ;;
    "src/ui/"*) reviewers+=("frontend-team") ;;
    "docs/"*) reviewers+=("docs-team") ;;
  esac
done

# Remove duplicates and assign
unique_reviewers=($(printf "%s\n" "${reviewers[@]}" | sort -u))
for reviewer in "${unique_reviewers[@]}"; do
  gh pr edit "$PR_NUMBER" --add-reviewer "$reviewer"
done

# Step 3: Create review checklist
echo "Step 3: Creating review checklist..."
gh pr comment "$PR_NUMBER" --body "## Review Checklist
- [ ] Code follows project style guidelines
- [ ] Tests are included and passing
- [ ] Documentation is updated
- [ ] Security considerations addressed
- [ ] Performance impact assessed

Generated by team review workflow"

echo "✅ Team review workflow completed for PR #$PR_NUMBER"
```

### Mentorship Program

#### Junior Developer Support

```bash
#!/bin/bash
# mentorship-suggestions.sh

OWNER="$1"
REPO="$2"
PR_NUMBER="$3"

# Get PR author
author=$(gh pr view "$PR_NUMBER" --json author --jq '.author.login')

# Check if author is in junior developers list
junior_devs=("alice" "bob" "charlie")
if [[ " ${junior_devs[@]} " =~ " ${author} " ]]; then
  echo "Creating educational suggestions for junior developer: $author"
  
  # Get files in PR
  files=$(gh pr view "$PR_NUMBER" --json files --jq '.files[].path')
  
  for file in $files; do
    # Check for common junior developer issues
    
    # 1. Console.log statements
    if grep -n "console.log" "$file"; then
      line_numbers=$(grep -n "console.log" "$file" | cut -d: -f1)
      for line in $line_numbers; do
        ./create-suggestion.sh "$OWNER" "$REPO" "$PR_NUMBER" "$file" "$line" \
          "// Consider using a proper logging library instead of console.log" \
          "💡 Learning: Use proper logging for production code"
      done
    fi
    
    # 2. Missing error handling
    if grep -n "await.*(" "$file" && ! grep -n "try.*catch" "$file"; then
      line_number=$(grep -n "await" "$file" | head -1 | cut -d: -f1)
      ./create-suggestion.sh "$OWNER" "$REPO" "$PR_NUMBER" "$file" "$line_number" \
        "try {
  // Your async code here
} catch (error) {
  console.error('Error:', error);
  // Handle error appropriately
}" "💡 Learning: Always handle errors in async functions"
    fi
  done
  
  # Add educational comment
  gh pr comment "$PR_NUMBER" --body "👋 Hi $author! I've added some educational suggestions to help improve your code. These are learning opportunities - feel free to ask questions about any of the suggestions. Great work on the PR! 🚀"
fi
```

## Integration Examples

### Slack Integration

#### Suggestion Notifications

```bash
#!/bin/bash
# slack-suggestion-notifications.sh

WEBHOOK_URL="$SLACK_WEBHOOK_URL"
OWNER="$1"
REPO="$2"
PR_NUMBER="$3"

# Get suggestion count
suggestion_count=$(./manage-suggestions.sh list "$OWNER" "$REPO" "$PR_NUMBER" --output json | jq 'length')

if [ "$suggestion_count" -gt 0 ]; then
  # Get PR details
  pr_title=$(gh pr view "$PR_NUMBER" --json title --jq '.title')
  pr_url=$(gh pr view "$PR_NUMBER" --json url --jq '.url')
  pr_author=$(gh pr view "$PR_NUMBER" --json author --jq '.author.login')
  
  # Send Slack notification
  curl -X POST -H 'Content-type: application/json' \
    --data "{
      \"text\": \"📝 New suggestions available!\",
      \"blocks\": [
        {
          \"type\": \"section\",
          \"text\": {
            \"type\": \"mrkdwn\",
            \"text\": \"*$suggestion_count* new suggestions for PR <$pr_url|#$PR_NUMBER>\"
          }
        },
        {
          \"type\": \"section\",
          \"fields\": [
            {
              \"type\": \"mrkdwn\",
              \"text\": \"*Title:*\\n$pr_title\"
            },
            {
              \"type\": \"mrkdwn\",
              \"text\": \"*Author:*\\n@$pr_author\"
            }
          ]
        }
      ]
    }" \
    "$WEBHOOK_URL"
fi
```

### Jira Integration

#### Link Suggestions to Tickets

```bash
#!/bin/bash
# jira-suggestion-linking.sh

OWNER="$1"
REPO="$2"
PR_NUMBER="$3"

# Extract Jira ticket from PR title or branch
pr_title=$(gh pr view "$PR_NUMBER" --json title --jq '.title')
ticket_id=$(echo "$pr_title" | grep -oE "[A-Z]+-[0-9]+")

if [ -n "$ticket_id" ]; then
  echo "Found Jira ticket: $ticket_id"
  
  # Get suggestions
  suggestions=$(./manage-suggestions.sh list "$OWNER" "$REPO" "$PR_NUMBER" --output json)
  suggestion_count=$(echo "$suggestions" | jq 'length')
  
  if [ "$suggestion_count" -gt 0 ]; then
    # Create Jira comment
    pr_url=$(gh pr view "$PR_NUMBER" --json url --jq '.url')
    
    jira_comment="Code review suggestions available for PR #$PR_NUMBER:
    
$suggestion_count suggestions have been created for this PR.
View and apply suggestions: $pr_url

Top suggestions:
$(echo "$suggestions" | jq -r '.[:3][] | "• \(.description // "Code improvement")"')"
    
    # Add comment to Jira (requires Jira CLI or API)
    echo "Would add comment to Jira ticket $ticket_id:"
    echo "$jira_comment"
  fi
fi
```

### IDE Integration

#### VS Code Extension Support

```bash
#!/bin/bash
# vscode-suggestions.sh

OWNER="$1"
REPO="$2"
PR_NUMBER="$3"

# Generate VS Code task for applying suggestions
cat > .vscode/apply-suggestions.json << EOF
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Apply PR Suggestions",
      "type": "shell",
      "command": "./manage-suggestions.sh",
      "args": [
        "list",
        "$OWNER",
        "$REPO",
        "$PR_NUMBER",
        "--output",
        "json"
      ],
      "group": "build",
      "presentation": {
        "reveal": "always",
        "panel": "new"
      },
      "problemMatcher": []
    }
  ]
}
EOF

echo "VS Code task created: .vscode/apply-suggestions.json"
```

## Troubleshooting Scenarios

### Common Error Recovery

#### Handle Rate Limiting

```bash
#!/bin/bash
# rate-limit-handler.sh

create_suggestion_with_retry() {
  local max_retries=3
  local retry_count=0
  
  while [ $retry_count -lt $max_retries ]; do
    # Check rate limit before making request
    rate_remaining=$(gh api rate_limit --jq '.rate.remaining')
    
    if [ "$rate_remaining" -lt 10 ]; then
      echo "Rate limit low ($rate_remaining remaining), waiting 60 seconds..."
      sleep 60
      continue
    fi
    
    # Try to create suggestion
    if ./create-suggestion.sh "$@"; then
      echo "Suggestion created successfully"
      return 0
    else
      retry_count=$((retry_count + 1))
      echo "Attempt $retry_count failed, retrying in $((retry_count * 2)) seconds..."
      sleep $((retry_count * 2))
    fi
  done
  
  echo "Failed to create suggestion after $max_retries attempts"
  return 1
}

# Usage
create_suggestion_with_retry myorg myproject 123 "src/main.js" 45 "fixed code" "Fix issue"
```

#### Handle Network Issues

```bash
#!/bin/bash
# network-resilience.sh

robust_api_call() {
  local endpoint="$1"
  local max_attempts=5
  local attempt=1
  
  while [ $attempt -le $max_attempts ]; do
    echo "Attempt $attempt/$max_attempts for $endpoint"
    
    if response=$(gh api "$endpoint" 2>/dev/null); then
      echo "$response"
      return 0
    fi
    
    case $? in
      6)  # Network unreachable
        echo "Network error, waiting 30 seconds..."
        sleep 30
        ;;
      22) # HTTP error
        echo "HTTP error, checking status..."
        # Check if it's a temporary server error
        sleep 10
        ;;
      *)  # Other errors
        echo "Unknown error, waiting 10 seconds..."
        sleep 10
        ;;
    esac
    
    attempt=$((attempt + 1))
  done
  
  echo "Failed after $max_attempts attempts"
  return 1
}
```

#### Validate Suggestions Before Creation

```bash
#!/bin/bash
# suggestion-validator.sh

validate_suggestion() {
  local file="$1"
  local line_number="$2"
  local suggestion="$3"
  
  # Check if file exists in PR
  if ! gh pr view "$PR_NUMBER" --json files --jq '.files[].path' | grep -q "^$file$"; then
    echo "Error: File $file not found in PR"
    return 1
  fi
  
  # Check if line number is reasonable
  if [ "$line_number" -lt 1 ] || [ "$line_number" -gt 10000 ]; then
    echo "Error: Invalid line number $line_number"
    return 1
  fi
  
  # Check suggestion format
  if [ -z "$suggestion" ]; then
    echo "Error: Empty suggestion"
    return 1
  fi
  
  # Check for special characters that might break the API
  if echo "$suggestion" | grep -q $'\x00'; then
    echo "Error: Suggestion contains null bytes"
    return 1
  fi
  
  return 0
}

# Safe suggestion creation
safe_create_suggestion() {
  if validate_suggestion "$4" "$5" "$6"; then
    ./create-suggestion.sh "$@"
  else
    echo "Validation failed, skipping suggestion"
    return 1
  fi
}
```

---

These examples demonstrate practical, real-world usage of GitHub PR suggestions functionality. Adapt them to your specific workflow and organizational needs.