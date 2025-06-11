#!/bin/bash

# GitHub Sub-Issues Query Operations Script
# Provides READ operations for sub-issue relationships
# Usage: ./github-sub-issues-query.sh [operation] [repo] [issue_number]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
VERBOSE=false
OUTPUT_FORMAT="table"

# Help function
show_help() {
    cat << EOF
GitHub Sub-Issues Query Operations

USAGE:
    $0 [OPTIONS] OPERATION REPO [ISSUE_NUMBER]

OPERATIONS:
    list-sub-issues REPO ISSUE_NUMBER    List all sub-issues of a parent issue
    get-parent REPO ISSUE_NUMBER         Get parent issue of a sub-issue
    show-hierarchy REPO ISSUE_NUMBER     Display hierarchical structure
    get-issue-info REPO ISSUE_NUMBER     Get detailed issue information

OPTIONS:
    -v, --verbose           Enable verbose output
    -f, --format FORMAT     Output format: table, json, csv (default: table)
    -h, --help             Show this help message

EXAMPLES:
    $0 list-sub-issues AcmeInc/example-project 1
    $0 get-parent AcmeInc/example-project 2
    $0 show-hierarchy AcmeInc/example-project 1 --verbose
    $0 get-issue-info AcmeInc/example-project 1 --format json

REQUIREMENTS:
    - GitHub CLI (gh) must be installed and authenticated
    - Repository must have sub-issues feature enabled
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

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                break
                ;;
        esac
    done
    
    OPERATION="$1"
    REPO="$2"
    ISSUE_NUMBER="$3"
}

# Validate inputs
validate_inputs() {
    if [[ -z "$OPERATION" ]]; then
        log_error "Operation is required"
        show_help
        exit 1
    fi
    
    if [[ -z "$REPO" ]]; then
        log_error "Repository is required"
        show_help
        exit 1
    fi
    
    if [[ "$OPERATION" != "show-hierarchy" && -z "$ISSUE_NUMBER" ]]; then
        log_error "Issue number is required for this operation"
        show_help
        exit 1
    fi
    
    # Validate repository format
    if [[ ! "$REPO" =~ ^[^/]+/[^/]+$ ]]; then
        log_error "Repository must be in format 'owner/repo'"
        exit 1
    fi
    
    # Validate issue number
    if [[ -n "$ISSUE_NUMBER" && ! "$ISSUE_NUMBER" =~ ^[0-9]+$ ]]; then
        log_error "Issue number must be a positive integer"
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
            }
        }
    }'
    
    local owner="${repo%/*}"
    local name="${repo#*/}"
    
    local result=$(gh api graphql \
        --field query="$query" \
        --field owner="$owner" \
        --field name="$name" \
        --field number="$issue_num" \
        --jq '.data.repository.issue.id' 2>/dev/null)
    
    if [[ -z "$result" || "$result" == "null" ]]; then
        log_error "Issue #$issue_num not found in repository $repo"
        exit 1
    fi
    
    echo "$result"
}

# List sub-issues of a parent issue
list_sub_issues() {
    local repo="$1"
    local issue_num="$2"
    
    log_info "Listing sub-issues for issue #$issue_num in $repo"
    
    local owner="${repo%/*}"
    local name="${repo#*/}"
    
    local query='
    query($owner: String!, $name: String!, $number: Int!) {
        repository(owner: $owner, name: $name) {
            issue(number: $number) {
                title
                number
                state
                subIssues(first: 100) {
                    totalCount
                    nodes {
                        title
                        number
                        state
                        url
                        assignees(first: 10) {
                            nodes {
                                login
                            }
                        }
                        labels(first: 10) {
                            nodes {
                                name
                            }
                        }
                        createdAt
                        updatedAt
                    }
                }
            }
        }
    }'
    
    local result=$(gh api graphql \
        --field query="$query" \
        --field owner="$owner" \
        --field name="$name" \
        --field number="$issue_num")
    
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo "$result" | jq '.data.repository.issue.subIssues'
        return
    fi
    
    local parent_title=$(echo "$result" | jq -r '.data.repository.issue.title')
    local total_count=$(echo "$result" | jq -r '.data.repository.issue.subIssues.totalCount')
    
    if [[ "$total_count" == "0" ]]; then
        log_warning "Issue #$issue_num '$parent_title' has no sub-issues"
        return
    fi
    
    log_success "Found $total_count sub-issues for issue #$issue_num '$parent_title'"
    
    if [[ "$OUTPUT_FORMAT" == "table" ]]; then
        echo
        printf "%-5s %-50s %-10s %-20s %-30s\n" "NUM" "TITLE" "STATE" "ASSIGNEES" "LABELS"
        printf "%-5s %-50s %-10s %-20s %-30s\n" "---" "-----" "-----" "---------" "------"
        
        echo "$result" | jq -r '.data.repository.issue.subIssues.nodes[] | 
            [
                .number,
                (.title | if length > 47 then .[:47] + "..." else . end),
                .state,
                (.assignees.nodes | map(.login) | join(",") | if length > 17 then .[:17] + "..." else . end),
                (.labels.nodes | map(.name) | join(",") | if length > 27 then .[:27] + "..." else . end)
            ] | @tsv' | while IFS=$'\t' read -r num title state assignees labels; do
            printf "%-5s %-50s %-10s %-20s %-30s\n" "$num" "$title" "$state" "$assignees" "$labels"
        done
    elif [[ "$OUTPUT_FORMAT" == "csv" ]]; then
        echo "Number,Title,State,URL,Assignees,Labels,Created,Updated"
        echo "$result" | jq -r '.data.repository.issue.subIssues.nodes[] | 
            [
                .number,
                .title,
                .state,
                .url,
                (.assignees.nodes | map(.login) | join(";")),
                (.labels.nodes | map(.name) | join(";")),
                .createdAt,
                .updatedAt
            ] | @csv'
    fi
}

# Get parent issue of a sub-issue
get_parent() {
    local repo="$1"
    local issue_num="$2"
    
    log_info "Getting parent issue for issue #$issue_num in $repo"
    
    local owner="${repo%/*}"
    local name="${repo#*/}"
    
    local query='
    query($owner: String!, $name: String!, $number: Int!) {
        repository(owner: $owner, name: $name) {
            issue(number: $number) {
                title
                number
                state
                parent {
                    title
                    number
                    state
                    url
                    assignees(first: 10) {
                        nodes {
                            login
                        }
                    }
                    labels(first: 10) {
                        nodes {
                            name
                        }
                    }
                    createdAt
                    updatedAt
                }
            }
        }
    }'
    
    local result=$(gh api graphql \
        --field query="$query" \
        --field owner="$owner" \
        --field name="$name" \
        --field number="$issue_num")
    
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo "$result" | jq '.data.repository.issue.parent'
        return
    fi
    
    local issue_title=$(echo "$result" | jq -r '.data.repository.issue.title')
    local parent_data=$(echo "$result" | jq -r '.data.repository.issue.parent')
    
    if [[ "$parent_data" == "null" ]]; then
        log_warning "Issue #$issue_num '$issue_title' has no parent issue"
        return
    fi
    
    local parent_num=$(echo "$result" | jq -r '.data.repository.issue.parent.number')
    local parent_title=$(echo "$result" | jq -r '.data.repository.issue.parent.title')
    
    log_success "Found parent issue for #$issue_num '$issue_title'"
    
    if [[ "$OUTPUT_FORMAT" == "table" ]]; then
        echo
        printf "%-10s %-50s %-10s %-20s %-30s\n" "PARENT #" "TITLE" "STATE" "ASSIGNEES" "LABELS"
        printf "%-10s %-50s %-10s %-20s %-30s\n" "--------" "-----" "-----" "---------" "------"
        
        echo "$result" | jq -r '.data.repository.issue.parent | 
            [
                .number,
                (.title | if length > 47 then .[:47] + "..." else . end),
                .state,
                (.assignees.nodes | map(.login) | join(",") | if length > 17 then .[:17] + "..." else . end),
                (.labels.nodes | map(.name) | join(",") | if length > 27 then .[:27] + "..." else . end)
            ] | @tsv' | while IFS=$'\t' read -r num title state assignees labels; do
            printf "%-10s %-50s %-10s %-20s %-30s\n" "$num" "$title" "$state" "$assignees" "$labels"
        done
    elif [[ "$OUTPUT_FORMAT" == "csv" ]]; then
        echo "Number,Title,State,URL,Assignees,Labels,Created,Updated"
        echo "$result" | jq -r '.data.repository.issue.parent | 
            [
                .number,
                .title,
                .state,
                .url,
                (.assignees.nodes | map(.login) | join(";")),
                (.labels.nodes | map(.name) | join(";")),
                .createdAt,
                .updatedAt
            ] | @csv'
    fi
}

# Show hierarchical structure
show_hierarchy() {
    local repo="$1"
    local issue_num="$2"
    
    log_info "Showing hierarchy for issue #$issue_num in $repo"
    
    # First, check if this issue has a parent (it's a sub-issue)
    local owner="${repo%/*}"
    local name="${repo#*/}"
    
    local parent_query='
    query($owner: String!, $name: String!, $number: Int!) {
        repository(owner: $owner, name: $name) {
            issue(number: $number) {
                title
                number
                parent {
                    title
                    number
                }
            }
        }
    }'
    
    local parent_result=$(gh api graphql \
        --field query="$parent_query" \
        --field owner="$owner" \
        --field name="$name" \
        --field number="$issue_num")
    
    local parent_data=$(echo "$parent_result" | jq -r '.data.repository.issue.parent')
    
    if [[ "$parent_data" != "null" ]]; then
        # This is a sub-issue, show from parent
        local parent_num=$(echo "$parent_result" | jq -r '.data.repository.issue.parent.number')
        log_info "Issue #$issue_num is a sub-issue. Showing hierarchy from parent #$parent_num"
        issue_num="$parent_num"
    fi
    
    # Now show the full hierarchy
    local hierarchy_query='
    query($owner: String!, $name: String!, $number: Int!) {
        repository(owner: $owner, name: $name) {
            issue(number: $number) {
                title
                number
                state
                subIssues(first: 100) {
                    totalCount
                    nodes {
                        title
                        number
                        state
                        subIssues(first: 100) {
                            totalCount
                            nodes {
                                title
                                number
                                state
                            }
                        }
                    }
                }
            }
        }
    }'
    
    local result=$(gh api graphql \
        --field query="$hierarchy_query" \
        --field owner="$owner" \
        --field name="$name" \
        --field number="$issue_num")
    
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo "$result" | jq '.data.repository.issue'
        return
    fi
    
    echo
    echo "ISSUE HIERARCHY:"
    echo "=================="
    
    # Show parent issue
    local parent_title=$(echo "$result" | jq -r '.data.repository.issue.title')
    local parent_state=$(echo "$result" | jq -r '.data.repository.issue.state')
    echo "├── #$issue_num: $parent_title [$parent_state]"
    
    # Show sub-issues
    local total_subs=$(echo "$result" | jq -r '.data.repository.issue.subIssues.totalCount')
    
    if [[ "$total_subs" == "0" ]]; then
        echo "    └── (no sub-issues)"
    else
        echo "$result" | jq -r '.data.repository.issue.subIssues.nodes[] | 
            [
                .number,
                .title,
                .state,
                .subIssues.totalCount
            ] | @tsv' | while IFS=$'\t' read -r num title state sub_count; do
            if [[ "$sub_count" == "0" ]]; then
                echo "    ├── #$num: $title [$state]"
            else
                echo "    ├── #$num: $title [$state] ($sub_count sub-issues)"
            fi
        done
    fi
}

# Get detailed issue information
get_issue_info() {
    local repo="$1"
    local issue_num="$2"
    
    log_info "Getting detailed information for issue #$issue_num in $repo"
    
    local owner="${repo%/*}"
    local name="${repo#*/}"
    
    local query='
    query($owner: String!, $name: String!, $number: Int!) {
        repository(owner: $owner, name: $name) {
            issue(number: $number) {
                title
                number
                state
                url
                body
                assignees(first: 10) {
                    nodes {
                        login
                    }
                }
                labels(first: 10) {
                    nodes {
                        name
                        color
                    }
                }
                createdAt
                updatedAt
                author {
                    login
                }
                parent {
                    title
                    number
                }
                subIssues(first: 100) {
                    totalCount
                }
            }
        }
    }'
    
    local result=$(gh api graphql \
        --field query="$query" \
        --field owner="$owner" \
        --field name="$name" \
        --field number="$issue_num")
    
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo "$result" | jq '.data.repository.issue'
        return
    fi
    
    echo
    echo "ISSUE DETAILS:"
    echo "=============="
    
    local title=$(echo "$result" | jq -r '.data.repository.issue.title')
    local state=$(echo "$result" | jq -r '.data.repository.issue.state')
    local url=$(echo "$result" | jq -r '.data.repository.issue.url')
    local author=$(echo "$result" | jq -r '.data.repository.issue.author.login')
    local created=$(echo "$result" | jq -r '.data.repository.issue.createdAt')
    local updated=$(echo "$result" | jq -r '.data.repository.issue.updatedAt')
    local assignees=$(echo "$result" | jq -r '.data.repository.issue.assignees.nodes | map(.login) | join(", ")')
    local labels=$(echo "$result" | jq -r '.data.repository.issue.labels.nodes | map(.name) | join(", ")')
    local parent_data=$(echo "$result" | jq -r '.data.repository.issue.parent')
    local sub_count=$(echo "$result" | jq -r '.data.repository.issue.subIssues.totalCount')
    
    printf "%-15s %s\n" "Number:" "#$issue_num"
    printf "%-15s %s\n" "Title:" "$title"
    printf "%-15s %s\n" "State:" "$state"
    printf "%-15s %s\n" "Author:" "$author"
    printf "%-15s %s\n" "URL:" "$url"
    printf "%-15s %s\n" "Created:" "$created"
    printf "%-15s %s\n" "Updated:" "$updated"
    
    if [[ -n "$assignees" && "$assignees" != "" ]]; then
        printf "%-15s %s\n" "Assignees:" "$assignees"
    fi
    
    if [[ -n "$labels" && "$labels" != "" ]]; then
        printf "%-15s %s\n" "Labels:" "$labels"
    fi
    
    if [[ "$parent_data" != "null" ]]; then
        local parent_num=$(echo "$result" | jq -r '.data.repository.issue.parent.number')
        local parent_title=$(echo "$result" | jq -r '.data.repository.issue.parent.title')
        printf "%-15s #%s: %s\n" "Parent Issue:" "$parent_num" "$parent_title"
    fi
    
    printf "%-15s %s\n" "Sub-issues:" "$sub_count"
}

# Main execution
main() {
    parse_args "$@"
    validate_inputs
    check_prerequisites
    
    case "$OPERATION" in
        list-sub-issues)
            list_sub_issues "$REPO" "$ISSUE_NUMBER"
            ;;
        get-parent)
            get_parent "$REPO" "$ISSUE_NUMBER"
            ;;
        show-hierarchy)
            show_hierarchy "$REPO" "$ISSUE_NUMBER"
            ;;
        get-issue-info)
            get_issue_info "$REPO" "$ISSUE_NUMBER"
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