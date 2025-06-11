#!/bin/bash
#
# GitHub Projects Item Management - Issues to Projects CRUD Operations
# 
# This script provides comprehensive CRUD operations for managing issues in GitHub Projects.
# It supports adding, removing, listing, and bulk operations for project items.
#
# Usage Examples:
#   ./github-projects-item-management.sh add-issue 1 AcmeInc https://github.com/AcmeInc/example-project/issues/1
#   ./github-projects-item-management.sh remove-item 1 AcmeInc PVTI_kwExampleProjectID
#   ./github-projects-item-management.sh list-items 1 AcmeInc
#   ./github-projects-item-management.sh bulk-add 1 AcmeInc issue_urls.txt
#
# Requirements:
# - GitHub CLI (gh) with authentication
# - read:project and project scopes
# - jq for JSON processing
#

set -e

# Script configuration
VERSION="1.0.0"
SCRIPT_NAME="github-projects-item-management"
LOG_FILE="/tmp/${SCRIPT_NAME}.log"
MAX_RETRIES=3
RETRY_DELAY=2

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    log "ERROR: $1"
    exit 1
}

# Success message
success() {
    echo -e "${GREEN}✓ $1${NC}"
    log "SUCCESS: $1"
}

# Warning message
warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    log "WARNING: $1"
}

# Info message
info() {
    echo -e "${BLUE}ℹ $1${NC}"
    log "INFO: $1"
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

# Validate GitHub CLI authentication and scopes
validate_auth() {
    if ! gh auth status >/dev/null 2>&1; then
        error_exit "GitHub CLI not authenticated. Please run: gh auth login --scopes project"
    fi
    
    # Check for project scope
    if ! gh auth status 2>&1 | grep -q "project\|read:project"; then
        warning "Project scope may not be available. Consider running: gh auth refresh -s project --hostname github.com"
        info "You may need to manually authorize project access at: https://github.com/settings/tokens"
    fi
}

# Get project ID from project number and owner
get_project_id() {
    local project_num="$1"
    local owner="$2"
    
    local project_id
    if [[ "$owner" == *"/"* ]]; then
        # User project
        local username=$(echo "$owner" | cut -d'/' -f1)
        project_id=$(retry_command "gh api graphql -f query='query{ user(login: \"$username\"){ projectV2(number: $project_num) { id } } }'" | jq -r '.data.user.projectV2.id')
    else
        # Organization project
        project_id=$(retry_command "gh api graphql -f query='query{ organization(login: \"$owner\"){ projectV2(number: $project_num) { id } } }'" | jq -r '.data.organization.projectV2.id')
    fi
    
    if [ -z "$project_id" ] || [ "$project_id" = "null" ]; then
        error_exit "Could not find project $project_num for owner $owner"
    fi
    
    echo "$project_id"
}

# Extract issue/PR content ID from URL
get_content_id() {
    local url="$1"
    
    # Extract owner/repo/number from URL
    if [[ "$url" =~ github\.com/([^/]+)/([^/]+)/(issues|pull)/([0-9]+) ]]; then
        local owner="${BASH_REMATCH[1]}"
        local repo="${BASH_REMATCH[2]}"
        local type="${BASH_REMATCH[3]}"
        local number="${BASH_REMATCH[4]}"
        
        # Query for content ID
        local content_id
        if [ "$type" = "issues" ]; then
            content_id=$(retry_command "gh api graphql -f query='query{ repository(owner: \"$owner\", name: \"$repo\"){ issue(number: $number) { id } } }'" | jq -r '.data.repository.issue.id')
        else
            content_id=$(retry_command "gh api graphql -f query='query{ repository(owner: \"$owner\", name: \"$repo\"){ pullRequest(number: $number) { id } } }'" | jq -r '.data.repository.pullRequest.id')
        fi
        
        if [ -z "$content_id" ] || [ "$content_id" = "null" ]; then
            error_exit "Could not find content ID for $url"
        fi
        
        echo "$content_id"
    else
        error_exit "Invalid GitHub URL format: $url"
    fi
}

# Add issue/PR to project
add_issue_to_project() {
    local project_num="$1"
    local owner="$2"
    local issue_url="$3"
    
    info "Adding $issue_url to project $project_num (owner: $owner)"
    
    # Get project ID
    local project_id
    project_id=$(get_project_id "$project_num" "$owner")
    info "Project ID: $project_id"
    
    # Get content ID
    local content_id
    content_id=$(get_content_id "$issue_url")
    info "Content ID: $content_id"
    
    # Add item to project
    local mutation='mutation($projectId: ID!, $contentId: ID!) {
        addProjectV2ItemById(input: {
            projectId: $projectId
            contentId: $contentId
        }) {
            item {
                id
                content {
                    ... on Issue {
                        title
                        number
                        url
                    }
                    ... on PullRequest {
                        title
                        number
                        url
                    }
                }
            }
        }
    }'
    
    local result
    result=$(retry_command "gh api graphql -f query='$mutation' -F projectId='$project_id' -F contentId='$content_id'")
    
    local item_id
    item_id=$(echo "$result" | jq -r '.data.addProjectV2ItemById.item.id')
    
    if [ -z "$item_id" ] || [ "$item_id" = "null" ]; then
        # Check if already exists
        if echo "$result" | jq -r '.errors[]?.message' | grep -qi "already exists\|duplicate"; then
            warning "Item already exists in project"
            return 0
        else
            error_exit "Failed to add item to project: $(echo "$result" | jq -r '.errors[]?.message' | head -1)"
        fi
    fi
    
    local title
    title=$(echo "$result" | jq -r '.data.addProjectV2ItemById.item.content.title')
    
    success "Added '$title' to project (Item ID: $item_id)"
    echo "$item_id"
}

# Remove item from project
remove_item_from_project() {
    local project_num="$1"
    local owner="$2"
    local item_id="$3"
    
    info "Removing item $item_id from project $project_num (owner: $owner)"
    
    # Get project ID
    local project_id
    project_id=$(get_project_id "$project_num" "$owner")
    
    # Remove item from project
    local mutation='mutation($projectId: ID!, $itemId: ID!) {
        deleteProjectV2Item(input: {
            projectId: $projectId
            itemId: $itemId
        }) {
            deletedItemId
        }
    }'
    
    local result
    result=$(retry_command "gh api graphql -f query='$mutation' -F projectId='$project_id' -F itemId='$item_id'")
    
    local deleted_id
    deleted_id=$(echo "$result" | jq -r '.data.deleteProjectV2Item.deletedItemId')
    
    if [ -z "$deleted_id" ] || [ "$deleted_id" = "null" ]; then
        error_exit "Failed to remove item from project: $(echo "$result" | jq -r '.errors[]?.message' | head -1)"
    fi
    
    success "Removed item from project (Deleted ID: $deleted_id)"
}

# List all items in project
list_project_items() {
    local project_num="$1"
    local owner="$2"
    local format="${3:-table}"
    
    info "Listing items in project $project_num (owner: $owner)"
    
    # Get project ID
    local project_id
    project_id=$(get_project_id "$project_num" "$owner")
    
    # Query project items
    local query='query($projectId: ID!) {
        node(id: $projectId) {
            ... on ProjectV2 {
                title
                items(first: 100) {
                    nodes {
                        id
                        type
                        content {
                            ... on Issue {
                                title
                                number
                                url
                                state
                                assignees(first: 5) {
                                    nodes {
                                        login
                                    }
                                }
                                labels(first: 10) {
                                    nodes {
                                        name
                                    }
                                }
                            }
                            ... on PullRequest {
                                title
                                number
                                url
                                state
                                assignees(first: 5) {
                                    nodes {
                                        login
                                    }
                                }
                            }
                            ... on DraftIssue {
                                title
                            }
                        }
                        fieldValues(first: 20) {
                            nodes {
                                ... on ProjectV2ItemFieldTextValue {
                                    field {
                                        ... on ProjectV2Field {
                                            name
                                        }
                                    }
                                    text
                                }
                                ... on ProjectV2ItemFieldSingleSelectValue {
                                    field {
                                        ... on ProjectV2SingleSelectField {
                                            name
                                        }
                                    }
                                    name
                                }
                                ... on ProjectV2ItemFieldDateValue {
                                    field {
                                        ... on ProjectV2Field {
                                            name
                                        }
                                    }
                                    date
                                }
                                ... on ProjectV2ItemFieldNumberValue {
                                    field {
                                        ... on ProjectV2Field {
                                            name
                                        }
                                    }
                                    number
                                }
                            }
                        }
                    }
                }
            }
        }
    }'
    
    local result
    result=$(retry_command "gh api graphql -f query='$query' -F projectId='$project_id'")
    
    if [ "$format" = "json" ]; then
        echo "$result" | jq '.'
        return
    fi
    
    if [ "$format" = "csv" ]; then
        echo "Item ID,Type,Title,Number,URL,State,Assignees,Labels,Custom Fields"
        echo "$result" | jq -r '
        .data.node.items.nodes[] |
        [
            .id,
            .type,
            .content.title // "N/A",
            .content.number // "N/A",
            .content.url // "N/A", 
            .content.state // "N/A",
            ([.content.assignees.nodes[]?.login] | join(";")),
            ([.content.labels.nodes[]?.name] | join(";")),
            ([.fieldValues.nodes[] | select(.field.name != null) | "\(.field.name):\(.text // .name // .date // .number // "N/A")"] | join(";"))
        ] | @csv'
        return
    fi
    
    # Table format (default)
    local project_title
    project_title=$(echo "$result" | jq -r '.data.node.title')
    
    echo -e "\n${BLUE}=== Project: $project_title ===${NC}"
    echo
    
    local items
    items=$(echo "$result" | jq -r '.data.node.items.nodes | length')
    
    if [ "$items" = "0" ]; then
        info "No items found in project"
        return
    fi
    
    printf "%-32s %-12s %-50s %-8s %-20s %-20s\n" "ITEM ID" "TYPE" "TITLE" "NUMBER" "STATE" "ASSIGNEES"
    printf "%-32s %-12s %-50s %-8s %-20s %-20s\n" "$(printf '%.32s' "--------------------------------")" "$(printf '%.12s' "------------")" "$(printf '%.50s' "--------------------------------------------------")" "$(printf '%.8s' "--------")" "$(printf '%.20s' "--------------------")" "$(printf '%.20s' "--------------------")"
    
    echo "$result" | jq -r '
    .data.node.items.nodes[] |
    [
        .id,
        .type,
        (.content.title // "N/A" | if length > 47 then .[0:47] + "..." else . end),
        (.content.number // "N/A" | tostring),
        (.content.state // "N/A"),
        ([.content.assignees.nodes[]?.login] | join(",") | if length > 17 then .[0:17] + "..." else . end)
    ] | @tsv' | \
    while IFS=$'\t' read -r item_id type title number state assignees; do
        printf "%-32s %-12s %-50s %-8s %-20s %-20s\n" "$item_id" "$type" "$title" "$number" "$state" "$assignees"
    done
    
    echo
    success "Listed $items items from project"
}

# Bulk add issues from file
bulk_add_issues() {
    local project_num="$1"
    local owner="$2"
    local file="$3"
    
    if [ ! -f "$file" ]; then
        error_exit "File not found: $file"
    fi
    
    info "Bulk adding issues from $file to project $project_num (owner: $owner)"
    
    local added=0
    local failed=0
    local skipped=0
    
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Extract URL (handle lines with additional metadata)
        local url
        url=$(echo "$line" | awk '{print $1}')
        
        info "Processing: $url"
        
        if add_issue_to_project "$project_num" "$owner" "$url" >/dev/null 2>&1; then
            added=$((added + 1))
            success "Added: $url"
        else
            failed=$((failed + 1))
            warning "Failed to add: $url"
        fi
        
        # Rate limiting: small delay between requests
        sleep 0.5
    done < "$file"
    
    echo
    success "Bulk add complete: $added added, $failed failed, $skipped skipped"
}

# Bulk remove items from file
bulk_remove_items() {
    local project_num="$1"
    local owner="$2"
    local file="$3"
    
    if [ ! -f "$file" ]; then
        error_exit "File not found: $file"
    fi
    
    info "Bulk removing items from $file from project $project_num (owner: $owner)"
    
    local removed=0
    local failed=0
    
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Extract item ID
        local item_id
        item_id=$(echo "$line" | awk '{print $1}')
        
        info "Processing: $item_id"
        
        if remove_item_from_project "$project_num" "$owner" "$item_id" >/dev/null 2>&1; then
            removed=$((removed + 1))
            success "Removed: $item_id"
        else
            failed=$((failed + 1))
            warning "Failed to remove: $item_id"
        fi
        
        # Rate limiting: small delay between requests
        sleep 0.5
    done < "$file"
    
    echo
    success "Bulk remove complete: $removed removed, $failed failed"
}

# Show usage information
show_usage() {
    cat << EOF
${BLUE}GitHub Projects Item Management v$VERSION${NC}

${GREEN}DESCRIPTION:${NC}
    Comprehensive CRUD operations for managing issues and pull requests in GitHub Projects.
    Supports individual and bulk operations with comprehensive error handling.

${GREEN}USAGE:${NC}
    $0 <command> <project_number> <owner> [arguments...]

${GREEN}COMMANDS:${NC}
    ${YELLOW}add-issue${NC} <project_num> <owner> <issue_url>
        Add an issue or pull request to the project
        
    ${YELLOW}remove-item${NC} <project_num> <owner> <item_id>
        Remove an item from the project by item ID
        
    ${YELLOW}list-items${NC} <project_num> <owner> [format]
        List all items in the project
        Formats: table (default), json, csv
        
    ${YELLOW}bulk-add${NC} <project_num> <owner> <file>
        Add multiple issues from a file (one URL per line)
        
    ${YELLOW}bulk-remove${NC} <project_num> <owner> <file>
        Remove multiple items from a file (one item ID per line)
        
    ${YELLOW}get-project-id${NC} <project_num> <owner>
        Get the project ID for a given project number and owner

${GREEN}EXAMPLES:${NC}
    # Add single issue to project
    $0 add-issue 1 AcmeInc https://github.com/AcmeInc/example-project/issues/1
    
    # Remove item from project  
    $0 remove-item 1 AcmeInc PVTI_kwExampleProjectID
    
    # List all items in table format
    $0 list-items 1 AcmeInc
    
    # List all items in JSON format
    $0 list-items 1 AcmeInc json
    
    # Bulk add issues from file
    $0 bulk-add 1 AcmeInc issue_urls.txt
    
    # Bulk remove items from file  
    $0 bulk-remove 1 AcmeInc item_ids.txt

${GREEN}OWNER FORMATS:${NC}
    - Organization: ${YELLOW}orgname${NC}
    - User: ${YELLOW}username${NC}
    - Current user: ${YELLOW}@me${NC}

${GREEN}REQUIREMENTS:${NC}
    - GitHub CLI (gh) installed and authenticated
    - Project scopes: read:project, project
    - jq for JSON processing
    - Internet connection

${GREEN}FILES:${NC}
    Log file: $LOG_FILE
    
${GREEN}AUTHENTICATION:${NC}
    Run: gh auth refresh -s project --hostname github.com
    Or visit: https://github.com/settings/tokens

EOF
}

# Main function
main() {
    local command="$1"
    
    # Handle help and version
    case "$command" in
        -h|--help|help)
            show_usage
            exit 0
            ;;
        -v|--version|version)
            echo "$SCRIPT_NAME v$VERSION"
            exit 0
            ;;
    esac
    
    # Validate dependencies
    if ! command -v gh >/dev/null 2>&1; then
        error_exit "GitHub CLI (gh) is not installed. Please install from: https://cli.github.com/"
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        error_exit "jq is not installed. Please install jq for JSON processing."
    fi
    
    # Validate authentication
    validate_auth
    
    # Process commands
    case "$command" in
        add-issue)
            if [ $# -ne 4 ]; then
                error_exit "Usage: $0 add-issue <project_num> <owner> <issue_url>"
            fi
            add_issue_to_project "$2" "$3" "$4"
            ;;
        remove-item)
            if [ $# -ne 4 ]; then
                error_exit "Usage: $0 remove-item <project_num> <owner> <item_id>"
            fi
            remove_item_from_project "$2" "$3" "$4"
            ;;
        list-items)
            if [ $# -lt 3 ]; then
                error_exit "Usage: $0 list-items <project_num> <owner> [format]"
            fi
            list_project_items "$2" "$3" "${4:-table}"
            ;;
        bulk-add)
            if [ $# -ne 4 ]; then
                error_exit "Usage: $0 bulk-add <project_num> <owner> <file>"
            fi
            bulk_add_issues "$2" "$3" "$4"
            ;;
        bulk-remove)
            if [ $# -ne 4 ]; then
                error_exit "Usage: $0 bulk-remove <project_num> <owner> <file>"
            fi
            bulk_remove_items "$2" "$3" "$4"
            ;;
        get-project-id)
            if [ $# -ne 3 ]; then
                error_exit "Usage: $0 get-project-id <project_num> <owner>"
            fi
            get_project_id "$2" "$3"
            ;;
        *)
            if [ -z "$command" ]; then
                show_usage
                exit 0
            else
                error_exit "Unknown command: $command. Use '$0 --help' for usage information."
            fi
            ;;
    esac
}

# Handle script interruption
trap 'echo -e "\n${YELLOW}Script interrupted${NC}"; exit 130' INT TERM

# Run main function
main "$@"