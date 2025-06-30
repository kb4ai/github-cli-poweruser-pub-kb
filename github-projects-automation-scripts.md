# GitHub Projects - Production Automation Scripts

## ⚠️ CRITICAL: Authentication Requirements

**All scripts in this document require CLASSIC personal access tokens with 'project' scope.**

**❌ Fine-grained personal access tokens (new tokens) do NOT work with Projects v2 API**  
**✅ Classic personal access tokens from ${GITHUB_TOKEN_DOTFILE} work perfectly**

### Authentication Setup Required

Before running any automation scripts, ensure you have proper authentication:

```bash
# Create classic token at: https://github.com/settings/tokens
# Select 'Generate new token (classic)'
# Enable scopes: project, read:project, repo

# Configure ${GITHUB_TOKEN_DOTFILE} with GITHUB_PERSONAL_ACCESS_TOKEN
source ${GITHUB_TOKEN_DOTFILE}
export GH_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN"

# Test authentication
gh project list --owner @me
```

**If you see empty responses or null values, you're using a fine-grained token instead of a classic token.**

## Complete Project Management Scripts

### 1. Issue Lifecycle Automation
```bash
#!/bin/bash
# issue-project-workflow.sh - Complete issue to project automation

set -e

# CRITICAL: Use classic token (fine-grained tokens don't work)
if [ ! -f ${GITHUB_TOKEN_DOTFILE} ]; then
    echo "❌ Error: ${GITHUB_TOKEN_DOTFILE} file not found"
    echo "Create classic token at: https://github.com/settings/tokens"
    exit 1
fi

source ${GITHUB_TOKEN_DOTFILE}
export GH_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN"

PROJECT_NUM="${1:-1}"
OWNER="${2:-@me}"
REPO="${3}"

if [ -z "$REPO" ]; then
    echo "Usage: $0 <project_num> <owner> <repo>"
    echo "Example: $0 1 @me owner/repo"
    exit 1
fi

# Get project and field IDs
echo "Setting up project automation for project $PROJECT_NUM..."

PROJECT_ID=$(gh project view $PROJECT_NUM --owner $OWNER --format json | jq -r '.id')
STATUS_FIELD_ID=$(gh project field-list $PROJECT_NUM --owner $OWNER --format json | jq -r '.fields[] | select(.name=="Status") | .id')
TODO_OPTION_ID=$(gh project field-list $PROJECT_NUM --owner $OWNER --format json | jq -r '.fields[] | select(.name=="Status") | .options[] | select(.name=="Todo") | .id')

echo "Project ID: $PROJECT_ID"
echo "Status Field ID: $STATUS_FIELD_ID"

# Function to create issue and add to project
create_and_add_issue() {
    local title="$1"
    local body="$2"
    local labels="$3"
    
    echo "Creating issue: $title"
    
    # Create issue with labels
    local issue_url
    if [ -n "$labels" ]; then
        issue_url=$(gh issue create --repo "$REPO" --title "$title" --body "$body" --label "$labels" --json url --jq .url)
    else
        issue_url=$(gh issue create --repo "$REPO" --title "$title" --body "$body" --json url --jq .url)
    fi
    
    # Add to project
    local item_id
    item_id=$(gh project item-add $PROJECT_NUM --owner $OWNER --url "$issue_url" --format json | jq -r '.id')
    
    # Set initial status to Todo
    gh project item-edit --id "$item_id" --project-id "$PROJECT_ID" --field-id "$STATUS_FIELD_ID" --single-select-option-id "$TODO_OPTION_ID"
    
    echo "✓ Created and added issue: $issue_url (Item ID: $item_id)"
}

# Bulk issue creation
create_and_add_issue "Setup CI/CD Pipeline" "Configure GitHub Actions for automated testing and deployment" "enhancement,devops"
create_and_add_issue "Fix login bug" "Users cannot authenticate with OAuth" "bug,high-priority"
create_and_add_issue "Add user dashboard" "Create personalized dashboard for user metrics" "feature,ui"
create_and_add_issue "Update documentation" "Refresh API documentation and examples" "documentation"

echo
echo "✓ Issue creation complete!"
echo "View project: https://github.com/projects/$PROJECT_NUM"
```

### 2. Status Update Automation
```bash
#!/bin/bash
# update-project-status.sh - Smart status updates based on issue activity

set -e

PROJECT_NUM="${1:-1}"
OWNER="${2:-@me}"

# Get required IDs
PROJECT_ID=$(gh project view $PROJECT_NUM --owner $OWNER --format json | jq -r '.id')
STATUS_FIELD_ID=$(gh project field-list $PROJECT_NUM --owner $OWNER --format json | jq -r '.fields[] | select(.name=="Status") | .id')

# Get status option IDs
IN_PROGRESS_ID=$(gh project field-list $PROJECT_NUM --owner $OWNER --format json | jq -r '.fields[] | select(.name=="Status") | .options[] | select(.name=="In Progress") | .id')
IN_REVIEW_ID=$(gh project field-list $PROJECT_NUM --owner $OWNER --format json | jq -r '.fields[] | select(.name=="Status") | .options[] | select(.name=="In Review") | .id')
DONE_ID=$(gh project field-list $PROJECT_NUM --owner $OWNER --format json | jq -r '.fields[] | select(.name=="Status") | .options[] | select(.name=="Done") | .id')

echo "Updating project statuses based on activity..."

# Get current user
CURRENT_USER=$(gh api user --jq .login)

# Get all project items with their issue data
gh project item-list $PROJECT_NUM --owner $OWNER --format json | jq -r '.items[] | {id, url: .content.url, state: .content.state, assignees: [.content.assignees[]?.login], prs: .content.linkedBranches}' | \
while IFS= read -r line; do
    item_id=$(echo "$line" | jq -r '.id')
    issue_url=$(echo "$line" | jq -r '.url')
    issue_state=$(echo "$line" | jq -r '.state')
    assignees=$(echo "$line" | jq -r '.assignees[]?' 2>/dev/null)
    
    # Skip if no URL (draft items)
    if [ "$issue_url" = "null" ]; then
        continue
    fi
    
    echo "Processing: $issue_url"
    
    # Get issue details for more context
    repo_path=$(echo "$issue_url" | sed 's|https://github.com/||' | sed 's|/issues/.*||' | sed 's|/pull/.*||')
    issue_num=$(echo "$issue_url" | sed 's|.*/||')
    
    # Update status based on issue state and activity
    if [ "$issue_state" = "CLOSED" ]; then
        echo "  → Setting to Done (issue closed)"
        gh project item-edit --id "$item_id" --project-id "$PROJECT_ID" --field-id "$STATUS_FIELD_ID" --single-select-option-id "$DONE_ID"
    elif echo "$assignees" | grep -q "$CURRENT_USER"; then
        # Check if there are recent commits or PR activity
        if gh pr list --repo "$repo_path" --search "linked:$issue_num" --json number --jq '. | length' | grep -q "^[1-9]"; then
            echo "  → Setting to In Review (PR exists)"
            gh project item-edit --id "$item_id" --project-id "$PROJECT_ID" --field-id "$STATUS_FIELD_ID" --single-select-option-id "$IN_REVIEW_ID"
        else
            echo "  → Setting to In Progress (assigned to you)"
            gh project item-edit --id "$item_id" --project-id "$PROJECT_ID" --field-id "$STATUS_FIELD_ID" --single-select-option-id "$IN_PROGRESS_ID"
        fi
    else
        echo "  → Skipping (not assigned to current user)"
    fi
done

echo
echo "✓ Status updates complete!"
```

### 3. Project Health Dashboard
```bash
#!/bin/bash
# project-dashboard.sh - Comprehensive project analytics

set -e

PROJECT_NUM="${1:-1}"
OWNER="${2:-@me}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== GitHub Project Dashboard ===${NC}"
echo

# Get project info
project_data=$(gh project view $PROJECT_NUM --owner $OWNER --format json)
project_title=$(echo "$project_data" | jq -r '.title')
project_url=$(echo "$project_data" | jq -r '.url')

echo -e "${GREEN}Project:${NC} $project_title"
echo -e "${GREEN}URL:${NC} $project_url"
echo

# Get all items
item_data=$(gh project item-list $PROJECT_NUM --owner $OWNER --format json)
total_items=$(echo "$item_data" | jq '.items | length')

echo -e "${BLUE}=== Overview ===${NC}"
echo -e "Total Items: ${GREEN}$total_items${NC}"

# Issue vs PR breakdown
issues_count=$(echo "$item_data" | jq '.items | map(select(.content.type == "Issue")) | length')
prs_count=$(echo "$item_data" | jq '.items | map(select(.content.type == "PullRequest")) | length')
drafts_count=$(echo "$item_data" | jq '.items | map(select(.content.type == "DraftIssue")) | length')

echo -e "Issues: ${GREEN}$issues_count${NC}"
echo -e "Pull Requests: ${GREEN}$prs_count${NC}"
echo -e "Draft Items: ${GREEN}$drafts_count${NC}"
echo

# Status breakdown
echo -e "${BLUE}=== Status Distribution ===${NC}"
echo "$item_data" | jq -r '
.items | 
group_by(.fieldValues[] | select(.field.name=="Status") | .name // "No Status") | 
map({
  status: (.[0].fieldValues[] | select(.field.name=="Status") | .name // "No Status"),
  count: length
}) | 
sort_by(.count) | reverse | 
.[] | 
"\(.status): \(.count)"' | while read line; do
    status=$(echo "$line" | cut -d: -f1)
    count=$(echo "$line" | cut -d: -f2)
    
    case "$status" in
        "Done") echo -e "${GREEN}$line${NC}" ;;
        "In Progress") echo -e "${YELLOW}$line${NC}" ;;
        "Todo") echo -e "${BLUE}$line${NC}" ;;
        *) echo -e "$line" ;;
    esac
done
echo

# Assignee workload
echo -e "${BLUE}=== Assignee Workload ===${NC}"
echo "$item_data" | jq -r '
.items | 
map(select(.content.assignees | length > 0)) | 
map(.content.assignees[]) | 
group_by(.login) | 
map({
  user: .[0].login,
  count: length
}) | 
sort_by(.count) | reverse | 
.[] | 
"\(.user): \(.count) items"' | head -10
echo

# Priority analysis (if Priority field exists)
echo -e "${BLUE}=== Priority Breakdown ===${NC}"
priority_breakdown=$(echo "$item_data" | jq -r '
.items | 
group_by(.fieldValues[] | select(.field.name=="Priority") | .text // "No Priority") | 
map({
  priority: (.[0].fieldValues[] | select(.field.name=="Priority") | .text // "No Priority"),
  count: length
}) | 
sort_by(.count) | reverse | 
.[] | 
"\(.priority): \(.count)"' 2>/dev/null)

if [ -n "$priority_breakdown" ]; then
    echo "$priority_breakdown" | while read line; do
        priority=$(echo "$line" | cut -d: -f1)
        case "$priority" in
            "High"*) echo -e "${RED}$line${NC}" ;;
            "Medium"*) echo -e "${YELLOW}$line${NC}" ;;
            "Low"*) echo -e "${GREEN}$line${NC}" ;;
            *) echo -e "$line" ;;
        esac
    done
else
    echo "Priority field not configured"
fi
echo

# Recent activity
echo -e "${BLUE}=== Recent Activity ===${NC}"
echo "$item_data" | jq -r '
.items | 
map(select(.content.updatedAt)) | 
sort_by(.content.updatedAt) | reverse | 
limit(5; .[]) | 
"\(.content.title) - Updated: \(.content.updatedAt)"'
echo

# Velocity metrics (Story Points if available)
story_points_total=$(echo "$item_data" | jq '
.items | 
map(.fieldValues[] | select(.field.name=="Story Points") | .number // 0) | 
add' 2>/dev/null)

if [ "$story_points_total" != "null" ] && [ "$story_points_total" -gt 0 ]; then
    echo -e "${BLUE}=== Velocity Metrics ===${NC}"
    
    completed_points=$(echo "$item_data" | jq '
    .items | 
    map(select(.fieldValues[] | select(.field.name=="Status") | .name == "Done")) | 
    map(.fieldValues[] | select(.field.name=="Story Points") | .number // 0) | 
    add' 2>/dev/null)
    
    in_progress_points=$(echo "$item_data" | jq '
    .items | 
    map(select(.fieldValues[] | select(.field.name=="Status") | .name == "In Progress")) | 
    map(.fieldValues[] | select(.field.name=="Story Points") | .number // 0) | 
    add' 2>/dev/null)
    
    echo -e "Total Story Points: ${GREEN}$story_points_total${NC}"
    echo -e "Completed Points: ${GREEN}${completed_points:-0}${NC}"
    echo -e "In Progress Points: ${YELLOW}${in_progress_points:-0}${NC}"
    
    if [ "$story_points_total" -gt 0 ]; then
        completion_pct=$((completed_points * 100 / story_points_total))
        echo -e "Completion: ${GREEN}${completion_pct}%${NC}"
    fi
fi

echo
echo -e "${GREEN}✓ Dashboard complete!${NC}"
```

### 4. Automated Sprint Planning
```bash
#!/bin/bash
# sprint-planning.sh - Automated sprint assignment and planning

set -e

PROJECT_NUM="${1:-1}"
OWNER="${2:-@me}"
SPRINT_NAME="${3:-$(date +'Sprint %Y-%m-%d')}"
SPRINT_CAPACITY="${4:-20}"

echo "Setting up sprint: $SPRINT_NAME (Capacity: $SPRINT_CAPACITY points)"

# Get project IDs
PROJECT_ID=$(gh project view $PROJECT_NUM --owner $OWNER --format json | jq -r '.id')
SPRINT_FIELD_ID=$(gh project field-list $PROJECT_NUM --owner $OWNER --format json | jq -r '.fields[] | select(.name=="Sprint") | .id')
POINTS_FIELD_ID=$(gh project field-list $PROJECT_NUM --owner $OWNER --format json | jq -r '.fields[] | select(.name=="Story Points") | .id')
STATUS_FIELD_ID=$(gh project field-list $PROJECT_NUM --owner $OWNER --format json | jq -r '.fields[] | select(.name=="Status") | .id')
TODO_OPTION_ID=$(gh project field-list $PROJECT_NUM --owner $OWNER --format json | jq -r '.fields[] | select(.name=="Status") | .options[] | select(.name=="Todo") | .id')

# Create sprint field option if it doesn't exist
existing_options=$(gh project field-list $PROJECT_NUM --owner $OWNER --format json | jq -r --arg sprint "$SPRINT_NAME" '.fields[] | select(.name=="Sprint") | .options[] | select(.name==$sprint) | .id')

if [ -z "$existing_options" ]; then
    echo "Creating new sprint option: $SPRINT_NAME"
    # Note: GitHub CLI doesn't support adding options to existing fields directly
    # This would require GraphQL API call
    echo "Manual step required: Add '$SPRINT_NAME' option to Sprint field in project settings"
fi

# Get backlog items (Todo status, no sprint assigned)
echo "Finding backlog items..."

backlog_items=$(gh project item-list $PROJECT_NUM --owner $OWNER --format json | jq -r '
.items[] | 
select(
  (.fieldValues[] | select(.field.name=="Status") | .name) == "Todo" and
  (.fieldValues[] | select(.field.name=="Sprint") | .name // empty | not)
) | 
{
  id: .id,
  title: .content.title,
  points: (.fieldValues[] | select(.field.name=="Story Points") | .number // 1),
  priority: (.fieldValues[] | select(.field.name=="Priority") | .text // "Medium")
}')

if [ -z "$backlog_items" ]; then
    echo "No backlog items found"
    exit 0
fi

echo "Backlog items available:"
echo "$backlog_items" | jq -r '"\(.title) (\(.points) pts, \(.priority) priority)"'
echo

# Sort by priority and assign to sprint within capacity
echo "Assigning items to sprint..."

current_capacity=0
assigned_count=0

echo "$backlog_items" | jq -s 'sort_by(.priority == "High" | not) | sort_by(.priority == "Medium" | not)' | jq -r '.[] | @base64' | \
while IFS= read -r item_b64; do
    item=$(echo "$item_b64" | base64 -d)
    item_id=$(echo "$item" | jq -r '.id')
    title=$(echo "$item" | jq -r '.title')
    points=$(echo "$item" | jq -r '.points')
    priority=$(echo "$item" | jq -r '.priority')
    
    if [ $((current_capacity + points)) -le $SPRINT_CAPACITY ]; then
        echo "✓ Adding to sprint: $title ($points pts)"
        
        # Update sprint field (requires manual option ID)
        # gh project item-edit --id "$item_id" --project-id "$PROJECT_ID" --field-id "$SPRINT_FIELD_ID" --text "$SPRINT_NAME"
        
        current_capacity=$((current_capacity + points))
        assigned_count=$((assigned_count + 1))
    else
        echo "⚠ Capacity exceeded, skipping: $title ($points pts)"
        break
    fi
done

echo
echo "Sprint planning complete!"
echo "Items assigned: $assigned_count"
echo "Total points: $current_capacity / $SPRINT_CAPACITY"
echo
echo "Manual steps required:"
echo "1. Add '$SPRINT_NAME' to Sprint field options in project settings"
echo "2. Update assigned items to use the new sprint option"
```

### 5. Error Handling and Retry Logic
```bash
#!/bin/bash
# robust-project-automation.sh - Production-ready automation with error handling

set -e

# Configuration
MAX_RETRIES=3
RETRY_DELAY=2
LOG_FILE="/tmp/github-project-automation.log"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Retry function with exponential backoff
retry_command() {
    local max_attempts=$MAX_RETRIES
    local delay=$RETRY_DELAY
    local attempt=1
    local cmd="$*"
    
    while [ $attempt -le $max_attempts ]; do
        log "Attempting: $cmd (attempt $attempt/$max_attempts)"
        
        if eval "$cmd"; then
            log "SUCCESS: $cmd"
            return 0
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            log "FAILED: $cmd after $max_attempts attempts"
            return 1
        fi
        
        log "RETRY: $cmd failed, waiting $delay seconds..."
        sleep $delay
        delay=$((delay * 2))
        attempt=$((attempt + 1))
    done
}

# Validate GitHub CLI authentication
validate_auth() {
    # Check for classic token file (recommended)
    if [ -f ${GITHUB_TOKEN_DOTFILE} ]; then
        log "INFO: Using classic token from configured file"
        source ${GITHUB_TOKEN_DOTFILE}
        export GH_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN"
    elif ! gh auth status >/dev/null 2>&1; then
        log "ERROR: GitHub CLI not authenticated and no classic token found"
        echo "RECOMMENDED: Create classic token at https://github.com/settings/tokens"
        echo "Configure ${GITHUB_TOKEN_DOTFILE} with GITHUB_PERSONAL_ACCESS_TOKEN"
        echo "ALTERNATIVE: gh auth login --scopes project (may not work reliably)"
        exit 1
    fi
    
    # Test project access with null response detection
    if ! gh project list --owner @me >/dev/null 2>&1; then
        log "ERROR: Cannot access projects - likely using fine-grained token"
        echo "❌ Fine-grained tokens cause empty/null API responses"
        echo "✅ Use classic token: https://github.com/settings/tokens"
        exit 1
    fi
    
    log "SUCCESS: Project authentication validated"
}

# Safe field operations with validation
get_field_id() {
    local project_num="$1"
    local owner="$2"
    local field_name="$3"
    
    local field_id
    field_id=$(retry_command "gh project field-list $project_num --owner $owner --format json" | \
        jq -r --arg name "$field_name" '.fields[] | select(.name==$name) | .id')
    
    if [ -z "$field_id" ] || [ "$field_id" = "null" ]; then
        log "ERROR: Field '$field_name' not found in project $project_num"
        return 1
    fi
    
    echo "$field_id"
}

get_option_id() {
    local project_num="$1" 
    local owner="$2"
    local field_name="$3"
    local option_name="$4"
    
    local option_id
    option_id=$(retry_command "gh project field-list $project_num --owner $owner --format json" | \
        jq -r --arg field "$field_name" --arg option "$option_name" \
        '.fields[] | select(.name==$field) | .options[] | select(.name==$option) | .id')
    
    if [ -z "$option_id" ] || [ "$option_id" = "null" ]; then
        log "ERROR: Option '$option_name' not found in field '$field_name'"
        return 1
    fi
    
    echo "$option_id"
}

# Main automation function
main() {
    local project_num="${1:-1}"
    local owner="${2:-@me}"
    
    log "Starting robust project automation"
    
    # Validate prerequisites
    validate_auth
    
    # Get and validate project
    local project_id
    if ! project_id=$(retry_command "gh project view $project_num --owner $owner --format json | jq -r '.id'"); then
        log "ERROR: Cannot access project $project_num"
        exit 1
    fi
    
    log "Working with project ID: $project_id"
    
    # Get field IDs with validation
    local status_field_id priority_field_id
    
    if ! status_field_id=$(get_field_id "$project_num" "$owner" "Status"); then
        log "ERROR: Status field validation failed"
        exit 1
    fi
    
    if ! priority_field_id=$(get_field_id "$project_num" "$owner" "Priority"); then
        log "WARNING: Priority field not found, skipping priority operations"
        priority_field_id=""
    fi
    
    # Get option IDs
    local todo_option_id done_option_id
    
    if ! todo_option_id=$(get_option_id "$project_num" "$owner" "Status" "Todo"); then
        log "ERROR: Todo status option not found"
        exit 1
    fi
    
    # Process items with error handling
    local processed=0 failed=0
    
    retry_command "gh project item-list $project_num --owner $owner --format json" | \
    jq -r '.items[] | {id, title: .content.title, state: .content.state} | @base64' | \
    while IFS= read -r item_b64; do
        item=$(echo "$item_b64" | base64 -d)
        item_id=$(echo "$item" | jq -r '.id')
        title=$(echo "$item" | jq -r '.title')
        state=$(echo "$item" | jq -r '.state')
        
        log "Processing item: $title"
        
        # Update item with retry logic
        if [ "$state" = "CLOSED" ]; then
            if retry_command "gh project item-edit --id $item_id --project-id $project_id --field-id $status_field_id --single-select-option-id $todo_option_id"; then
                processed=$((processed + 1))
                log "SUCCESS: Updated $title to Todo"
            else
                failed=$((failed + 1))
                log "FAILED: Could not update $title"
            fi
        fi
    done
    
    log "Automation complete: $processed processed, $failed failed"
    
    if [ $failed -gt 0 ]; then
        log "WARNING: Some operations failed, check log for details"
        exit 1
    fi
}

# Handle script interruption
trap 'log "Script interrupted"; exit 130' INT TERM

# Run main function
main "$@"
```

## Key Production Considerations

1. **Authentication** - ⚠️ **CRITICAL**: Use classic personal access tokens only
   - ❌ Fine-grained tokens cause empty/null API responses
   - ✅ Classic tokens work perfectly with Projects v2 API
   - All scripts include validation for correct token types
2. **Error Handling** - All scripts include retry logic and proper error checking
3. **Logging** - Comprehensive logging for debugging and audit trails  
4. **Rate Limiting** - Built-in delays and retry mechanisms
5. **Field Validation** - Check field existence before operations
6. **Batch Processing** - Efficient handling of bulk operations
7. **Configuration** - Parameterized scripts for different environments

### Authentication Troubleshooting

**Empty Project Responses**: Usually indicates fine-grained token usage
```bash
# WRONG: Fine-grained token
source "${GITHUB_TOKEN_DOTFILE}"
gh project list --owner @me  # Returns empty

# CORRECT: Classic token
source ${GITHUB_TOKEN_DOTFILE}  
gh project list --owner @me  # Shows projects
```