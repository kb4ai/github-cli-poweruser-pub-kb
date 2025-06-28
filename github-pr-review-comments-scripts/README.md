# GitHub PR Review Comments Scripts

This directory contains practical bash scripts for programmatically reading, filtering, exporting, and managing GitHub Pull Request review comments using GitHub CLI and API.

## 🚨 CRITICAL: Edit vs Reply Operations

**SAFETY WARNING**: Understanding the difference between EDITING and REPLYING is essential for safe comment management:

| Operation | Script | What It Does | Who Can Do It |
|-----------|--------|--------------|---------------|
| **EDIT** | `edit-comment.sh` | **Modifies existing comment content** | **Comment author OR admin only** |
| **REPLY** | `reply-to-comment.sh` | **Creates new comment in thread** | **Any collaborator** |

**⚠️ Always verify which operation you intend before proceeding!**

**For comprehensive safety information, see: [Edit vs Reply Guide](../github-pr-comments-edit-vs-reply-guide.md)**

## Scripts Overview

### 1. `basic-comment-reader.sh`
Basic script to read all review comments from a specific PR.

**Usage:**
```bash
./basic-comment-reader.sh OWNER REPO PR_NUMBER
```

**Example:**
```bash
./basic-comment-reader.sh octocat Hello-World 37
```

**Features:**

- Fetches both review comments (inline) and general PR comments
- Displays formatted output with file paths, line numbers, and timestamps
- Shows comment threading information
- Provides summary statistics

### 2. `filtered-comment-reader.sh`
Advanced script with filtering capabilities for targeted comment analysis.

**Usage:**
```bash
./filtered-comment-reader.sh OWNER REPO PR_NUMBER [OPTIONS]
```

**Options:**

- `-u, --user USER`: Filter comments by specific user
- `-f, --file PATH`: Filter comments by file path
- `-t, --text TEXT`: Filter comments containing specific text
- `-d, --days DAYS`: Filter comments from last N days
- `-r, --replies-only`: Show only reply comments
- `-o, --output FORMAT`: Output format (human|json|csv)

**Examples:**
```bash
# Filter by user
./filtered-comment-reader.sh octocat Hello-World 37 --user johndoe

# Filter by file and time
./filtered-comment-reader.sh octocat Hello-World 37 --file "src/main.js" --days 7

# Export as JSON
./filtered-comment-reader.sh octocat Hello-World 37 --text "LGTM" --output json

# Show only replies in CSV format
./filtered-comment-reader.sh octocat Hello-World 37 --replies-only --output csv
```

### 3. `comment-exporter.sh`
Comprehensive exporter supporting multiple output formats.

**Usage:**
```bash
./comment-exporter.sh OWNER REPO PR_NUMBER OUTPUT_FILE [FORMAT]
```

**Supported Formats:**

- `json`: Structured JSON with metadata
- `csv`: Comma-separated values for spreadsheet analysis
- `markdown`: Human-readable markdown report
- `html`: Styled HTML report
- `text`: Plain text format

**Examples:**
```bash
# Export as JSON (default)
./comment-exporter.sh octocat Hello-World 37 comments.json

# Export as CSV
./comment-exporter.sh octocat Hello-World 37 comments.csv csv

# Export as HTML report
./comment-exporter.sh octocat Hello-World 37 report.html html

# Export as Markdown
./comment-exporter.sh octocat Hello-World 37 report.md markdown
```

### 4. `edit-comment.sh` 
**⚠️ EDIT OPERATION**: Modify existing comment content.

**Usage:**
```bash
./edit-comment.sh OWNER REPO COMMENT_ID "New content"
```

**Example:**
```bash
./edit-comment.sh octocat Hello-World 123456789 "Updated: Fixed the typo in variable name"
```

**Safety Features:**
- **Permission validation**: Ensures you can edit the comment (author or admin)
- **Original content display**: Shows current content before editing
- **Confirmation prompt**: Requires explicit confirmation
- **Edit history preservation**: GitHub maintains edit history
- **Detailed error messages**: Clear troubleshooting information

**⚠️ CRITICAL**: You can only edit your own comments or need admin access!

### 5. `reply-to-comment.sh`
**🆕 REPLY OPERATION**: Create new comment in thread.

**Usage:**
```bash
./reply-to-comment.sh OWNER REPO PR_NUMBER COMMENT_ID "Reply message"
```

**Example:**
```bash
./reply-to-comment.sh FlowCortex flowcortex 107 2172519617 "Thanks for the feedback!"
```

**Threading Features:**
- **Creates new comment**: Gets unique ID and becomes permanent
- **Forms conversation thread**: Links to original comment
- **Notification triggers**: Alerts all thread participants
- **Safety confirmation**: Prompts before creating reply
- **Original comment display**: Shows context before replying

**⚠️ NOTE**: Any collaborator can reply (no need to be comment author)!

### 6. `resolve-conversation.sh`
Resolve PR review comment conversation threads using GraphQL API.

**Usage:**
```bash
./resolve-conversation.sh OWNER REPO PR_NUMBER COMMENT_ID
```

**Example:**
```bash
./resolve-conversation.sh FlowCortex flowcortex 107 2172519617
```

**Features:**
- Uses GraphQL to find review thread from comment ID
- Checks current resolution status
- Resolves conversation threads
- Requires write permissions to repository

### 7. `find-reply-resolve.sh`
Comprehensive script to find comments by text, reply to them, and resolve conversations.

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
- Handles rate limiting and error recovery

### 8. `batch-pr-analyzer.sh`
Batch analyzer for analyzing multiple PRs at once.

**Usage:**
```bash
./batch-pr-analyzer.sh OWNER REPO [OPTIONS]
```

**Options:**

- `-s, --state STATE`: PR state (open|closed|all) [default: all]
- `-d, --days DAYS`: Analyze PRs from last N days
- `-a, --author AUTHOR`: Filter PRs by author
- `-o, --output FILE`: Save analysis to file
- `-n, --max-prs N`: Maximum number of PRs to analyze [default: 10]
- `-v, --detailed`: Include detailed comment analysis

**Examples:**
```bash
# Analyze open PRs from last 30 days
./batch-pr-analyzer.sh octocat Hello-World --state open --days 30

# Detailed analysis of PRs by specific author
./batch-pr-analyzer.sh octocat Hello-World --author johndoe --detailed

# Analyze up to 20 PRs and save results
./batch-pr-analyzer.sh octocat Hello-World --max-prs 20 --output analysis.json
```

### 9. `test-safety-fixes.sh`
Test Suite for Comment Resolution Safety Fixes

**Usage:**
```bash
./test-safety-fixes.sh
```

**Features:**
- ✅ Tests safety mechanisms to prevent wrong comment resolution
- ✅ Validates fail-safe behavior for non-existent search terms  
- ✅ Confirms error handling for invalid comment IDs
- ✅ Comprehensive edge case testing
- ✅ Regression prevention for critical bugs
- ✅ JSON parsing validation
- ✅ Array bounds checking

**Test Categories:**
1. **Non-existent Search Term Safety**: Ensures scripts exit safely
2. **Invalid Comment ID Resolution**: Prevents processing invalid IDs
3. **Empty Search Validation**: Tests improved empty result detection
4. **Content Verification**: Validates comment text matching logic

## Prerequisites

### Required Tools

1. **GitHub CLI**: Install from [cli.github.com](https://cli.github.com)
2. **jq**: JSON processor - install via package manager
3. **bash**: Unix shell (standard on Linux/macOS)

### Authentication

Authenticate with GitHub CLI before using the scripts:

```bash
# Interactive authentication
gh auth login

# Or set token environment variable
export GITHUB_TOKEN="your-token-here"

# Verify authentication
gh auth status
```

### Permissions

Required permissions depend on repository visibility and operations:

**For Reading Comments:**
- **Public repositories**: No authentication required
- **Private repositories**: Read access to repository
- **Organization repositories**: Member or collaborator access

**For Posting Replies:**
- **All repositories**: Write access to repository
- **Authentication**: Valid GitHub token with repo scope
- **Review permissions**: Ability to comment on pull requests

**For Editing Comments:**
- **Comment Author**: Can edit their own comments only
- **Repository Admin**: Can edit any comment in repository
- **Organization Owner**: Can edit comments in organization repositories
- **⚠️ Critical**: Regular collaborators CANNOT edit others' comments

**For Replying to Comments:**
- **Any Collaborator**: Anyone with read/write access to repository
- **Repository Members**: All members of the repository
- **Organization Members**: Members with appropriate repository access
- **⚠️ Note**: Much more permissive than edit operations

**For Resolving Conversations:**
- **All repositories**: Write access to repository
- **GraphQL API access**: Valid GitHub token with repo scope
- **Review permissions**: Ability to resolve review threads

## 🚨 Safety Warnings

### Critical Operations

**EDITING Comments (`edit-comment.sh`):**
- ⚠️ **Permanently modifies** existing comment content
- ⚠️ **Only comment author or admin** can perform this operation
- ⚠️ **Original content is replaced** (edit history preserved)
- ⚠️ **Cannot be undone** easily (requires another edit)

**REPLYING to Comments (`reply-to-comment.sh`):**
- ⚠️ **Creates permanent new comment** in conversation history
- ⚠️ **Triggers notifications** to all thread participants
- ⚠️ **Cannot be undone** (only deleted after creation)
- ⚠️ **Any collaborator can reply** (no author restriction)

### Before Using Scripts

1. **Understand the operation**: Edit modifies existing, Reply creates new
2. **Check permissions**: Ensure you have the right access level
3. **Verify target**: Double-check comment ID and repository
4. **Read confirmations**: Scripts will prompt for safety confirmations
5. **Test on non-critical repos**: Practice with test repositories first

## Common Use Cases

### 1. Code Review Analysis

```bash
# Analyze review patterns for a specific PR
./filtered-comment-reader.sh owner repo 123 --output json > pr_analysis.json

# Get top commenters
jq '.[] | .user' pr_analysis.json | sort | uniq -c | sort -nr
```

### 2. Team Performance Metrics

```bash
# Analyze team's review activity over last month
./batch-pr-analyzer.sh owner repo --days 30 --detailed --output team_metrics.json

# Extract average comments per PR
jq '.analysis.summary.total_review_comments / .analysis.summary.total_prs' team_metrics.json
```

### 3. File-specific Review Patterns

```bash
# Find all comments on specific file across PRs
for pr in $(gh pr list --limit 50 --json number --jq '.[].number'); do
  ./filtered-comment-reader.sh owner repo $pr --file "src/critical.js" --output json
done
```

### 4. Export for Documentation

```bash
# Create HTML report for stakeholders
./comment-exporter.sh owner repo 123 review_report.html html

# Generate markdown for documentation
./comment-exporter.sh owner repo 123 review_summary.md markdown
```

## Advanced Usage

### Pipeline Integration

```bash
#!/bin/bash
# CI/CD pipeline integration example

# Analyze recent PRs
./batch-pr-analyzer.sh $REPO_OWNER $REPO_NAME --state closed --days 7 --output recent_analysis.json

# Check for review completeness
review_coverage=$(jq '.analysis.prs | map(select(.comment_stats.review_comments > 0)) | length' recent_analysis.json)
total_prs=$(jq '.analysis.prs | length' recent_analysis.json)

if [ $review_coverage -lt $(($total_prs * 80 / 100)) ]; then
  echo "Warning: Low review coverage detected"
  exit 1
fi
```

### Custom Filtering

```bash
# Find PRs with contentious discussions (many comments)
./batch-pr-analyzer.sh owner repo --detailed --output all_prs.json
jq '.analysis.prs[] | select(.comment_stats.total_comments > 20)' all_prs.json
```

### Data Processing

```bash
# Extract comment sentiment indicators
./filtered-comment-reader.sh owner repo 123 --output json | \
jq '.[] | select(.body | test("(LGTM|looks good|approve)"; "i"))' | \
jq -s 'length'
```

## Error Handling

All scripts include comprehensive error handling:

- **Authentication checks**: Verify GitHub CLI authentication
- **Repository validation**: Confirm repository and PR existence
- **Rate limiting**: Respect GitHub API rate limits
- **Network resilience**: Handle network timeouts and retries
- **Input validation**: Validate all parameters before execution

## Performance Considerations

### Large Repositories

For repositories with many PRs or comments:

```bash
# Use pagination efficiently
gh api --paginate repos/owner/repo/pulls/123/comments --jq '.[]'

# Process in batches
./batch-pr-analyzer.sh owner repo --max-prs 5 --state open
```

### Rate Limiting

Monitor API usage:

```bash
# Check current rate limit
gh api rate_limit | jq '.rate'

# Use scripts with delays for large datasets
for pr in $(seq 1 100); do
  ./basic-comment-reader.sh owner repo $pr
  sleep 1  # Avoid rate limiting
done
```

## Troubleshooting

### Common Issues

1. **"PR not found"**: Check PR number and repository access
2. **"Not authenticated"**: Run `gh auth login`
3. **"Empty response"**: PR may have no review comments
4. **"Rate limited"**: Wait or use authenticated requests

### Debug Mode

Enable verbose output:

```bash
# Add debug flag to gh commands
gh api repos/owner/repo/pulls/123/comments --verbose

# Check jq syntax
echo '[]' | jq '.[] | select(.test)'
```

## Best Practices

1. **Cache results** for repeated analysis
2. **Use appropriate output formats** for downstream processing
3. **Implement retry logic** for network reliability
4. **Validate inputs** before making API calls
5. **Monitor rate limits** in automated workflows
6. **Filter early** to reduce processing overhead

## Integration Examples

### Slack Notifications

```bash
# Weekly review summary
analysis=$(./batch-pr-analyzer.sh owner repo --days 7 --output /tmp/weekly.json)
summary=$(jq -r '.analysis.summary | "PRs: \(.total_prs), Comments: \(.total_review_comments)"' /tmp/weekly.json)
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Weekly Review Summary: '$summary'"}' \
  YOUR_SLACK_WEBHOOK_URL
```

### Automated Reports

```bash
# Daily HTML report generation
./comment-exporter.sh owner repo $(gh pr list --limit 1 --json number --jq '.[0].number') \
  reports/daily-$(date +%Y%m%d).html html
```

This collection of scripts provides a comprehensive toolkit for GitHub PR review comment analysis and automation.

## GitHub PR Suggestions Scripts

### 9. `create-suggestion.sh`
Create GitHub PR suggested changes programmatically using the GitHub API.

**Usage:**
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
- Creates single and multi-line suggestions
- Validates PR and repository existence
- Supports both direct comments and review-based suggestions
- Handles authentication automatically
- Provides detailed error messages and success feedback

### 10. `manage-suggestions.sh`
Comprehensive CRUD operations for GitHub PR suggestions.

**Usage:**
```bash
./manage-suggestions.sh COMMAND OWNER REPO PR_NUMBER [OPTIONS]
```

**Commands:**
- `list` - List all suggestions in a PR
- `show` - Show specific suggestion details
- `delete` - Delete a suggestion (removes the review comment)
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

Analyze suggestions:
```bash
./manage-suggestions.sh analyze octocat Hello-World 123 --output markdown
```

**Features:**
- Complete CRUD operations for suggestions
- Multiple output formats (human, JSON, CSV, markdown)
- Advanced filtering and search capabilities
- Detailed analytics and statistics
- Batch operations support

### 11. `suggestion-analyzer.sh`
Advanced analysis and reporting for GitHub PR suggestions across multiple PRs.

**Usage:**
```bash
./suggestion-analyzer.sh COMMAND OWNER REPO [OPTIONS]
```

**Commands:**
- `pr-analysis` - Analyze suggestions in a specific PR
- `repo-analysis` - Analyze suggestions across multiple PRs in repository
- `user-analysis` - Analyze suggestion patterns for specific users
- `file-analysis` - Analyze suggestions by file patterns
- `trend-analysis` - Analyze suggestion trends over time
- `team-metrics` - Generate team suggestion metrics
- `export-report` - Generate comprehensive reports

**Examples:**

Analyze specific PR:
```bash
./suggestion-analyzer.sh pr-analysis octocat Hello-World --pr 123
```

Repository-wide analysis:
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

**Features:**
- Cross-PR suggestion analysis
- Team collaboration metrics
- Trend analysis over time
- User behavior patterns
- File and code pattern analysis
- Comprehensive reporting (HTML, Markdown, JSON)
- Export capabilities for further analysis

## Comprehensive Documentation

### Suggestion Guides and References

1. **[GitHub PR Suggestions Guide](./github-pr-suggestions-guide.md)** - Complete implementation guide
   - Suggestion syntax reference
   - API endpoint documentation
   - Script usage examples
   - Best practices and limitations
   - Troubleshooting guide

2. **[GitHub PR Suggestions Examples](./github-pr-suggestions-examples.md)** - Practical workflows
   - Real-world usage scenarios
   - Advanced automation patterns
   - Team collaboration workflows
   - Integration examples
   - Troubleshooting scenarios

3. **[GitHub PR Suggestions API Reference](./github-pr-suggestions-api-reference.md)** - Technical reference
   - Complete API documentation
   - Authentication methods
   - Request/response formats
   - Error handling
   - Rate limiting strategies
   - Code examples in multiple languages

### Key Features of GitHub Suggestions

**Suggestion Syntax:**
```markdown
Optional description of the change

```suggestion
proposed code here
```
```

**API Capabilities:**
- **CREATE**: Use PR Review Comments API with suggestion markdown
- **READ**: Parse review comments to identify suggestion blocks  
- **UPDATE**: Not supported (delete and recreate)
- **DELETE**: Delete the review comment containing the suggestion
- **ACCEPT/REJECT**: UI-only operation (no programmatic API)

**Important Limitations:**
- No programmatic acceptance of suggestions (must use GitHub UI)
- Cannot modify suggestions after creation
- Position-based targeting requires accurate diff calculations
- Rate limiting applies to all API operations

This collection of scripts provides a comprehensive toolkit for GitHub PR review comment analysis and automation.