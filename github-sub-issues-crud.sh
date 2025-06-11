#!/bin/bash

# GitHub Sub-Issues CRUD Operations Script
# Provides CREATE, UPDATE, DELETE operations for sub-issue relationships
# Usage: ./github-sub-issues-crud.sh [operation] [options]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
VERBOSE=false
DRY_RUN=false
FORCE=false

# Help function
show_help() {
    cat << EOF
GitHub Sub-Issues CRUD Operations

USAGE:
    $0 [OPTIONS] OPERATION [OPERATION_OPTIONS]

OPERATIONS:
    create-sub-issue --repo REPO --parent PARENT_NUM --child CHILD_NUM
        Create a parent-child relationship between two existing issues
        
    create-issue-as-sub --repo REPO --parent PARENT_NUM --title "TITLE" [--body "BODY"]
        Create a new issue and add it as a sub-issue to parent
        
    remove-sub-issue --repo REPO --parent PARENT_NUM --child CHILD_NUM
        Remove parent-child relationship (child becomes standalone)
        
    move-sub-issue --repo REPO --from PARENT_NUM --to NEW_PARENT_NUM --child CHILD_NUM
        Move a sub-issue from one parent to another
        
    prioritize-sub-issue --repo REPO --parent PARENT_NUM --child CHILD_NUM --position POSITION
        Change the priority/position of a sub-issue in parent's list
        
    convert-to-sub-issue --repo REPO --parent PARENT_NUM --issue ISSUE_NUM
        Convert existing standalone issue to sub-issue

GLOBAL OPTIONS:
    -v, --verbose           Enable verbose output
    -n, --dry-run           Show what would be done without making changes
    -f, --force             Skip confirmation prompts
    -h, --help             Show this help message

EXAMPLES:
    # Create parent-child relationship
    $0 create-sub-issue --repo AcmeInc/example-project --parent 1 --child 2
    
    # Create new issue as sub-issue
    $0 create-issue-as-sub --repo AcmeInc/example-project --parent 1 --title "New Task"
    
    # Remove sub-issue relationship
    $0 remove-sub-issue --repo AcmeInc/example-project --parent 1 --child 2 --force
    
    # Move sub-issue to different parent
    $0 move-sub-issue --repo AcmeInc/example-project --from 1 --to 3 --child 2
    
    # Prioritize sub-issue (move to top)
    $0 prioritize-sub-issue --repo AcmeInc/example-project --parent 1 --child 2 --position 1

REQUIREMENTS:
    - GitHub CLI (gh) must be installed and authenticated
    - Repository must have sub-issues feature enabled
    - User must have write access to the repository
EOF
}

# Logging functions
log_info() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[INFO]${NC} $1" >&2
    fi
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_dry_run() {
    echo -e "${YELLOW}[DRY RUN]${NC} $1" >&2
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                log_error "Unknown global option: $1"
                show_help
                exit 1
                ;;
            *)
                break
                ;;
        esac
    done
    
    OPERATION="$1"
    shift
    
    # Parse operation-specific arguments
    case "$OPERATION" in
        create-sub-issue|remove-sub-issue)
            parse_parent_child_args "$@"
            ;;
        create-issue-as-sub)
            parse_create_issue_args "$@"
            ;;
        move-sub-issue)
            parse_move_args "$@"
            ;;
        prioritize-sub-issue)
            parse_prioritize_args "$@"
            ;;
        convert-to-sub-issue)
            parse_convert_args "$@"
            ;;
        *)
            if [[ -n "$OPERATION" ]]; then
                log_error "Unknown operation: $OPERATION"
            else
                log_error "Operation is required"
            fi
            show_help
            exit 1
            ;;
    esac
}

# Parse parent-child arguments
parse_parent_child_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --repo)
                REPO="$2"
                shift 2
                ;;
            --parent)
                PARENT_NUM="$2"
                shift 2
                ;;
            --child)
                CHILD_NUM="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option for $OPERATION: $1"
                exit 1
                ;;
        esac
    done
    
    if [[ -z "$REPO" || -z "$PARENT_NUM" || -z "$CHILD_NUM" ]]; then
        log_error "$OPERATION requires --repo, --parent, and --child options"
        exit 1
    fi
}

# Parse create issue arguments
parse_create_issue_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --repo)
                REPO="$2"
                shift 2
                ;;
            --parent)
                PARENT_NUM="$2"
                shift 2
                ;;
            --title)
                ISSUE_TITLE="$2"
                shift 2
                ;;
            --body)
                ISSUE_BODY="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option for $OPERATION: $1"
                exit 1
                ;;
        esac
    done
    
    if [[ -z "$REPO" || -z "$PARENT_NUM" || -z "$ISSUE_TITLE" ]]; then
        log_error "$OPERATION requires --repo, --parent, and --title options"
        exit 1
    fi
}

# Parse move arguments
parse_move_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --repo)
                REPO="$2"
                shift 2
                ;;
            --from)
                FROM_PARENT="$2"
                shift 2
                ;;
            --to)
                TO_PARENT="$2"
                shift 2
                ;;
            --child)
                CHILD_NUM="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option for $OPERATION: $1"
                exit 1
                ;;
        esac
    done
    
    if [[ -z "$REPO" || -z "$FROM_PARENT" || -z "$TO_PARENT" || -z "$CHILD_NUM" ]]; then
        log_error "$OPERATION requires --repo, --from, --to, and --child options"
        exit 1
    fi
}

# Parse prioritize arguments
parse_prioritize_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --repo)
                REPO="$2"
                shift 2
                ;;
            --parent)
                PARENT_NUM="$2"
                shift 2
                ;;
            --child)
                CHILD_NUM="$2"
                shift 2
                ;;
            --position)
                POSITION="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option for $OPERATION: $1"
                exit 1
                ;;
        esac
    done
    
    if [[ -z "$REPO" || -z "$PARENT_NUM" || -z "$CHILD_NUM" || -z "$POSITION" ]]; then
        log_error "$OPERATION requires --repo, --parent, --child, and --position options"
        exit 1
    fi
}

# Parse convert arguments
parse_convert_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --repo)
                REPO="$2"
                shift 2
                ;;
            --parent)
                PARENT_NUM="$2"
                shift 2
                ;;
            --issue)
                ISSUE_NUM="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option for $OPERATION: $1"
                exit 1
                ;;
        esac
    done
    
    if [[ -z "$REPO" || -z "$PARENT_NUM" || -z "$ISSUE_NUM" ]]; then
        log_error "$OPERATION requires --repo, --parent, and --issue options"
        exit 1
    fi
}

# Validate inputs
validate_inputs() {
    # Validate repository format
    if [[ ! "$REPO" =~ ^[^/]+/[^/]+$ ]]; then
        log_error "Repository must be in format 'owner/repo'"
        exit 1
    fi
    
    # Validate issue numbers
    if [[ -n "$PARENT_NUM" && ! "$PARENT_NUM" =~ ^[0-9]+$ ]]; then
        log_error "Parent issue number must be a positive integer"
        exit 1
    fi
    
    if [[ -n "$CHILD_NUM" && ! "$CHILD_NUM" =~ ^[0-9]+$ ]]; then
        log_error "Child issue number must be a positive integer"
        exit 1
    fi
    
    if [[ -n "$ISSUE_NUM" && ! "$ISSUE_NUM" =~ ^[0-9]+$ ]]; then
        log_error "Issue number must be a positive integer"
        exit 1
    fi
    
    if [[ -n "$FROM_PARENT" && ! "$FROM_PARENT" =~ ^[0-9]+$ ]]; then
        log_error "From parent issue number must be a positive integer"
        exit 1
    fi
    
    if [[ -n "$TO_PARENT" && ! "$TO_PARENT" =~ ^[0-9]+$ ]]; then
        log_error "To parent issue number must be a positive integer"
        exit 1
    fi
    
    if [[ -n "$POSITION" && ! "$POSITION" =~ ^[0-9]+$ ]]; then
        log_error "Position must be a positive integer"
        exit 1
    fi
}

# Check if gh CLI is available and authenticated
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) is not installed"
        exit 1
    fi
    
    if ! gh auth status &> /dev/null; then
        log_error "GitHub CLI is not authenticated. Run 'gh auth login' first"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

# Get issue GraphQL ID
get_issue_id() {
    local repo="$1"
    local issue_num="$2"
    
    log_info "Getting GraphQL ID for issue #$issue_num in $repo"
    
    local query='
    query($owner: String!, $name: String!, $number: Int!) {
        repository(owner: $owner, name: $name) {
            issue(number: $number) {
                id
                title
                state
            }
        }
    }'
    
    local owner="${repo%/*}"
    local name="${repo#*/}"
    
    local result=$(gh api graphql \
        --field query="$query" \
        --field owner="$owner" \
        --field name="$name" \
        --field number="$issue_num" 2>/dev/null)
    
    local issue_id=$(echo "$result" | jq -r '.data.repository.issue.id')
    local issue_title=$(echo "$result" | jq -r '.data.repository.issue.title')
    local issue_state=$(echo "$result" | jq -r '.data.repository.issue.state')
    
    if [[ -z "$issue_id" || "$issue_id" == "null" ]]; then
        log_error "Issue #$issue_num not found in repository $repo"
        exit 1
    fi
    
    log_info "Found issue #$issue_num: '$issue_title' [$issue_state]"
    echo "$issue_id"
}

# Confirmation prompt
confirm_action() {
    if [[ "$FORCE" == true ]]; then
        return 0
    fi
    
    echo -n "Are you sure you want to proceed? (y/N): "
    read -r response
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            log_warning "Operation cancelled by user"
            exit 0
            ;;
    esac
}

# Create sub-issue relationship
create_sub_issue() {
    local repo="$1"
    local parent_num="$2"
    local child_num="$3"
    
    log_info "Creating sub-issue relationship: #$parent_num -> #$child_num in $repo"
    
    # Get GraphQL IDs
    local parent_id=$(get_issue_id "$repo" "$parent_num")
    local child_id=$(get_issue_id "$repo" "$child_num")
    
    echo "Creating parent-child relationship:"
    echo "  Parent: #$parent_num"
    echo "  Child:  #$child_num"
    echo
    
    if [[ "$DRY_RUN" == true ]]; then
        log_dry_run "Would add issue #$child_num as sub-issue of #$parent_num"
        return 0
    fi
    
    confirm_action
    
    local mutation='
    mutation($issueId: ID!, $subIssueId: ID!) {
        addSubIssue(input: {
            issueId: $issueId
            subIssueId: $subIssueId
        }) {
            issue {
                title
                number
            }
            subIssue {
                title
                number
            }
        }
    }'
    
    local result=$(gh api graphql \
        --field query="$mutation" \
        --field issueId="$parent_id" \
        --field subIssueId="$child_id")
    
    local parent_title=$(echo "$result" | jq -r '.data.addSubIssue.issue.title')
    local child_title=$(echo "$result" | jq -r '.data.addSubIssue.subIssue.title')
    
    log_success "Successfully added sub-issue relationship"
    echo "  Parent: #$parent_num '$parent_title'"
    echo "  Child:  #$child_num '$child_title'"
}

# Create new issue as sub-issue
create_issue_as_sub() {
    local repo="$1"
    local parent_num="$2"
    local title="$3"
    local body="${4:-}"
    
    log_info "Creating new issue as sub-issue of #$parent_num in $repo"
    
    # Get parent GraphQL ID
    local parent_id=$(get_issue_id "$repo" "$parent_num")
    
    echo "Creating new issue as sub-issue:"
    echo "  Parent: #$parent_num"
    echo "  Title:  $title"
    if [[ -n "$body" ]]; then
        echo "  Body:   ${body:0:50}..."
    fi
    echo
    
    if [[ "$DRY_RUN" == true ]]; then
        log_dry_run "Would create new issue '$title' as sub-issue of #$parent_num"
        return 0
    fi
    
    confirm_action
    
    # Create the issue first
    log_info "Creating new issue..."
    local issue_url
    if [[ -n "$body" ]]; then
        issue_url=$(gh issue create --repo "$repo" --title "$title" --body "$body")
    else
        issue_url=$(gh issue create --repo "$repo" --title "$title")
    fi
    
    local new_issue_num=$(basename "$issue_url")
    log_success "Created issue #$new_issue_num"
    
    # Get the new issue's GraphQL ID
    local child_id=$(get_issue_id "$repo" "$new_issue_num")
    
    # Add as sub-issue
    log_info "Adding as sub-issue..."
    local mutation='
    mutation($issueId: ID!, $subIssueId: ID!) {
        addSubIssue(input: {
            issueId: $issueId
            subIssueId: $subIssueId
        }) {
            issue {
                title
                number
            }
            subIssue {
                title
                number
            }
        }
    }'
    
    local result=$(gh api graphql \
        --field query="$mutation" \
        --field issueId="$parent_id" \
        --field subIssueId="$child_id")
    
    local parent_title=$(echo "$result" | jq -r '.data.addSubIssue.issue.title')
    
    log_success "Successfully created issue as sub-issue"
    echo "  Parent: #$parent_num '$parent_title'"
    echo "  Child:  #$new_issue_num '$title'"
    echo "  URL:    $issue_url"
}

# Remove sub-issue relationship
remove_sub_issue() {
    local repo="$1"
    local parent_num="$2"
    local child_num="$3"
    
    log_info "Removing sub-issue relationship: #$parent_num -> #$child_num in $repo"
    
    # Get GraphQL IDs
    local parent_id=$(get_issue_id "$repo" "$parent_num")
    local child_id=$(get_issue_id "$repo" "$child_num")
    
    echo "Removing parent-child relationship:"
    echo "  Parent: #$parent_num"
    echo "  Child:  #$child_num (will become standalone)"
    echo
    
    if [[ "$DRY_RUN" == true ]]; then
        log_dry_run "Would remove sub-issue relationship between #$parent_num and #$child_num"
        return 0
    fi
    
    confirm_action
    
    local mutation='
    mutation($issueId: ID!, $subIssueId: ID!) {
        removeSubIssue(input: {
            issueId: $issueId
            subIssueId: $subIssueId
        }) {
            issue {
                title
                number
            }
            subIssue {
                title
                number
            }
        }
    }'
    
    local result=$(gh api graphql \
        --field query="$mutation" \
        --field issueId="$parent_id" \
        --field subIssueId="$child_id")
    
    local parent_title=$(echo "$result" | jq -r '.data.removeSubIssue.issue.title')
    local child_title=$(echo "$result" | jq -r '.data.removeSubIssue.subIssue.title')
    
    log_success "Successfully removed sub-issue relationship"
    echo "  Parent: #$parent_num '$parent_title'"
    echo "  Child:  #$child_num '$child_title' (now standalone)"
}

# Move sub-issue to different parent
move_sub_issue() {
    local repo="$1"
    local from_parent="$2"
    local to_parent="$3"
    local child_num="$4"
    
    log_info "Moving sub-issue #$child_num from #$from_parent to #$to_parent in $repo"
    
    # Get GraphQL IDs
    local from_parent_id=$(get_issue_id "$repo" "$from_parent")
    local to_parent_id=$(get_issue_id "$repo" "$to_parent")
    local child_id=$(get_issue_id "$repo" "$child_num")
    
    echo "Moving sub-issue:"
    echo "  Child:      #$child_num"
    echo "  From Parent: #$from_parent"
    echo "  To Parent:   #$to_parent"
    echo
    
    if [[ "$DRY_RUN" == true ]]; then
        log_dry_run "Would move sub-issue #$child_num from #$from_parent to #$to_parent"
        return 0
    fi
    
    confirm_action
    
    # Remove from current parent
    log_info "Removing from current parent..."
    local remove_mutation='
    mutation($issueId: ID!, $subIssueId: ID!) {
        removeSubIssue(input: {
            issueId: $issueId
            subIssueId: $subIssueId
        }) {
            issue {
                title
                number
            }
            subIssue {
                title
                number
            }
        }
    }'
    
    gh api graphql \
        --field query="$remove_mutation" \
        --field issueId="$from_parent_id" \
        --field subIssueId="$child_id" > /dev/null
    
    # Add to new parent
    log_info "Adding to new parent..."
    local add_mutation='
    mutation($issueId: ID!, $subIssueId: ID!) {
        addSubIssue(input: {
            issueId: $issueId
            subIssueId: $subIssueId
        }) {
            issue {
                title
                number
            }
            subIssue {
                title
                number
            }
        }
    }'
    
    local result=$(gh api graphql \
        --field query="$add_mutation" \
        --field issueId="$to_parent_id" \
        --field subIssueId="$child_id")
    
    local new_parent_title=$(echo "$result" | jq -r '.data.addSubIssue.issue.title')
    local child_title=$(echo "$result" | jq -r '.data.addSubIssue.subIssue.title')
    
    log_success "Successfully moved sub-issue"
    echo "  Child:      #$child_num '$child_title'"
    echo "  New Parent: #$to_parent '$new_parent_title'"
}

# Prioritize sub-issue (change position)
prioritize_sub_issue() {
    local repo="$1"
    local parent_num="$2"
    local child_num="$3"
    local position="$4"
    
    log_info "Prioritizing sub-issue #$child_num to position $position under #$parent_num in $repo"
    
    # Get GraphQL IDs
    local parent_id=$(get_issue_id "$repo" "$parent_num")
    local child_id=$(get_issue_id "$repo" "$child_num")
    
    echo "Reprioritizing sub-issue:"
    echo "  Parent:   #$parent_num"
    echo "  Child:    #$child_num"
    echo "  Position: $position"
    echo
    
    if [[ "$DRY_RUN" == true ]]; then
        log_dry_run "Would move sub-issue #$child_num to position $position under #$parent_num"
        return 0
    fi
    
    confirm_action
    
    local mutation='
    mutation($issueId: ID!, $subIssueId: ID!, $position: Int!) {
        reprioritizeSubIssue(input: {
            issueId: $issueId
            subIssueId: $subIssueId
            position: $position
        }) {
            issue {
                title
                number
            }
            subIssue {
                title
                number
            }
        }
    }'
    
    local result=$(gh api graphql \
        --field query="$mutation" \
        --field issueId="$parent_id" \
        --field subIssueId="$child_id" \
        --field position="$position")
    
    local parent_title=$(echo "$result" | jq -r '.data.reprioritizeSubIssue.issue.title')
    local child_title=$(echo "$result" | jq -r '.data.reprioritizeSubIssue.subIssue.title')
    
    log_success "Successfully reprioritized sub-issue"
    echo "  Parent: #$parent_num '$parent_title'"
    echo "  Child:  #$child_num '$child_title' (now at position $position)"
}

# Convert existing issue to sub-issue
convert_to_sub_issue() {
    local repo="$1"
    local parent_num="$2"
    local issue_num="$3"
    
    log_info "Converting issue #$issue_num to sub-issue of #$parent_num in $repo"
    
    # This is essentially the same as create_sub_issue, but with different messaging
    create_sub_issue "$repo" "$parent_num" "$issue_num"
}

# Main execution
main() {
    parse_args "$@"
    validate_inputs
    check_prerequisites
    
    case "$OPERATION" in
        create-sub-issue)
            create_sub_issue "$REPO" "$PARENT_NUM" "$CHILD_NUM"
            ;;
        create-issue-as-sub)
            create_issue_as_sub "$REPO" "$PARENT_NUM" "$ISSUE_TITLE" "$ISSUE_BODY"
            ;;
        remove-sub-issue)
            remove_sub_issue "$REPO" "$PARENT_NUM" "$CHILD_NUM"
            ;;
        move-sub-issue)
            move_sub_issue "$REPO" "$FROM_PARENT" "$TO_PARENT" "$CHILD_NUM"
            ;;
        prioritize-sub-issue)
            prioritize_sub_issue "$REPO" "$PARENT_NUM" "$CHILD_NUM" "$POSITION"
            ;;
        convert-to-sub-issue)
            convert_to_sub_issue "$REPO" "$PARENT_NUM" "$ISSUE_NUM"
            ;;
        *)
            log_error "Unknown operation: $OPERATION"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"