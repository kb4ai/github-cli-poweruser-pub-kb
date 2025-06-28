#!/bin/bash

# manage-suggestions.sh - Comprehensive CRUD operations for GitHub PR suggestions
# 
# This script provides full CRUD (Create, Read, Update, Delete) operations for
# GitHub Pull Request suggested changes. It can list, analyze, and manage
# suggestions across pull requests.
#
# Usage: ./manage-suggestions.sh COMMAND OWNER REPO PR_NUMBER [OPTIONS]
#
# Commands:
#   list         - List all suggestions in a PR
#   show         - Show details of a specific suggestion
#   delete       - Delete a suggestion (deletes the review comment)
#   analyze      - Analyze suggestions in a PR
#   export       - Export suggestions to various formats
#   stats        - Show suggestion statistics
#
# Examples:
#   # List all suggestions in PR
#   ./manage-suggestions.sh list octocat Hello-World 123
#
#   # Show specific suggestion details
#   ./manage-suggestions.sh show octocat Hello-World 123 --comment-id 456789
#
#   # Delete a suggestion
#   ./manage-suggestions.sh delete octocat Hello-World 123 --comment-id 456789
#
#   # Analyze all suggestions
#   ./manage-suggestions.sh analyze octocat Hello-World 123 --output json
#
#   # Export suggestions to file
#   ./manage-suggestions.sh export octocat Hello-World 123 --format markdown --output suggestions.md
#
# Requirements:
#   - GitHub CLI (gh) installed and authenticated
#   - jq for JSON processing
#   - Appropriate permissions for the repository

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variables
COMMAND=""
OWNER=""
REPO=""
PR_NUMBER=""
COMMENT_ID=""
OUTPUT_FORMAT="human"
OUTPUT_FILE=""
VERBOSE=false

# Function to display usage
usage() {
    echo "Usage: $0 COMMAND OWNER REPO PR_NUMBER [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  list         List all suggestions in a PR"
    echo "  show         Show details of a specific suggestion"
    echo "  delete       Delete a suggestion (deletes the review comment)"
    echo "  analyze      Analyze suggestions in a PR"
    echo "  export       Export suggestions to various formats"
    echo "  stats        Show suggestion statistics"
    echo ""
    echo "Options:"
    echo "  --comment-id ID     Specific comment ID for show/delete commands"
    echo "  --output FORMAT     Output format: human|json|csv|markdown"
    echo "  --file FILE         Output file (default: stdout)"
    echo "  --verbose           Enable verbose output"
    echo ""
    echo "Examples:"
    echo "  # List all suggestions in PR"
    echo "  $0 list octocat Hello-World 123"
    echo ""
    echo "  # Show specific suggestion details"
    echo "  $0 show octocat Hello-World 123 --comment-id 456789"
    echo ""
    echo "  # Delete a suggestion"
    echo "  $0 delete octocat Hello-World 123 --comment-id 456789"
    echo ""
    echo "  # Analyze all suggestions"
    echo "  $0 analyze octocat Hello-World 123 --output json"
    echo ""
    echo "  # Export suggestions to file"
    echo "  $0 export octocat Hello-World 123 --format markdown --file suggestions.md"
    exit 1
}

# Function to log messages with colors
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${PURPLE}[DEBUG]${NC} $1"
    fi
}

# Function to check if required tools are installed
check_dependencies() {
    local missing_tools=()
    
    if ! command -v gh &> /dev/null; then
        missing_tools+=("gh (GitHub CLI)")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools:"
        for tool in "${missing_tools[@]}"; do
            echo "  - $tool"
        done
        exit 1
    fi
}

# Function to check GitHub CLI authentication
check_auth() {
    if ! gh auth status &> /dev/null; then
        log_error "GitHub CLI is not authenticated. Please run 'gh auth login'."
        exit 1
    fi
}

# Function to validate PR exists
validate_pr() {
    local owner="$1"
    local repo="$2"
    local pr_number="$3"
    
    log_debug "Validating PR #$pr_number in $owner/$repo..."
    
    if ! gh api "repos/$owner/$repo/pulls/$pr_number" &> /dev/null; then
        log_error "PR #$pr_number not found in repository $owner/$repo"
        exit 1
    fi
    
    log_debug "PR #$pr_number found"
}

# Function to extract suggestions from review comments
extract_suggestions() {
    local owner="$1"
    local repo="$2"
    local pr_number="$3"
    
    log_debug "Extracting suggestions from PR #$pr_number..."
    
    # Get all review comments
    local comments
    comments=$(gh api "repos/$owner/$repo/pulls/$pr_number/comments" --paginate)
    
    if [ -z "$comments" ] || [ "$comments" = "[]" ]; then
        echo "[]"
        return
    fi
    
    # Filter comments that contain suggestion blocks
    echo "$comments" | jq '[.[] | select(.body | test("```suggestion\\s*\\n.*\\n```"; "ms")) | {
        id: .id,
        user: .user.login,
        body: .body,
        path: .path,
        position: .position,
        line: .line,
        original_line: .original_line,
        commit_id: .commit_id,
        created_at: .created_at,
        updated_at: .updated_at,
        url: .html_url,
        suggestion_content: (.body | capture("```suggestion\\s*\\n(?<content>.*?)\\n```"; "ms").content),
        description: (.body | split("```suggestion")[0] | rtrimstr("\n") | ltrimstr("\n"))
    }]'
}

# Function to get suggestion by comment ID
get_suggestion_by_id() {
    local owner="$1"
    local repo="$2"
    local pr_number="$3"
    local comment_id="$4"
    
    log_debug "Getting suggestion with comment ID $comment_id..."
    
    local suggestions
    suggestions=$(extract_suggestions "$owner" "$repo" "$pr_number")
    
    echo "$suggestions" | jq --arg id "$comment_id" '.[] | select(.id == ($id | tonumber))'
}

# Function to list all suggestions
cmd_list() {
    local owner="$1"
    local repo="$2"
    local pr_number="$3"
    
    log_info "Listing all suggestions in PR #$pr_number..."
    
    local suggestions
    suggestions=$(extract_suggestions "$owner" "$repo" "$pr_number")
    
    local count
    count=$(echo "$suggestions" | jq 'length')
    
    if [ "$count" -eq 0 ]; then
        log_info "No suggestions found in PR #$pr_number"
        return
    fi
    
    case "$OUTPUT_FORMAT" in
        "json")
            echo "$suggestions"
            ;;
        "csv")
            echo "ID,User,File,Line,Created,Description"
            echo "$suggestions" | jq -r '.[] | [.id, .user, .path, (.line // .position), .created_at, (.description // "")] | @csv'
            ;;
        "markdown")
            echo "# Suggestions in PR #$pr_number"
            echo ""
            echo "Total suggestions: $count"
            echo ""
            echo "$suggestions" | jq -r '.[] | "## Suggestion #\(.id)
- **User**: \(.user)
- **File**: \(.path)
- **Line**: \(.line // .position)
- **Created**: \(.created_at)
- **URL**: \(.url)

**Description:**
\(.description // "No description")

**Suggested Change:**
```
\(.suggestion_content)
```
"'
            ;;
        *)
            echo -e "${CYAN}Suggestions in PR #$pr_number${NC}"
            echo "Found $count suggestion(s):"
            echo ""
            echo "$suggestions" | jq -r '.[] | "ID: \(.id)
User: \(.user)
File: \(.path)
Line: \(.line // .position)
Created: \(.created_at)
Description: \(.description // "No description")
URL: \(.url)
Suggestion:
\(.suggestion_content)
───────────────────────────────────────
"'
            ;;
    esac
}

# Function to show specific suggestion details
cmd_show() {
    local owner="$1"
    local repo="$2"
    local pr_number="$3"
    
    if [ -z "$COMMENT_ID" ]; then
        log_error "Comment ID is required for show command. Use --comment-id option."
        exit 1
    fi
    
    log_info "Showing suggestion details for comment ID $COMMENT_ID..."
    
    local suggestion
    suggestion=$(get_suggestion_by_id "$owner" "$repo" "$pr_number" "$COMMENT_ID")
    
    if [ -z "$suggestion" ] || [ "$suggestion" = "null" ]; then
        log_error "Suggestion with comment ID $COMMENT_ID not found"
        exit 1
    fi
    
    case "$OUTPUT_FORMAT" in
        "json")
            echo "$suggestion"
            ;;
        *)
            echo -e "${CYAN}Suggestion Details${NC}"
            echo "$suggestion" | jq -r '"ID: \(.id)
User: \(.user)
File: \(.path)
Line: \(.line // .position)
Position: \(.position)
Original Line: \(.original_line // "N/A")
Commit ID: \(.commit_id)
Created: \(.created_at)
Updated: \(.updated_at)
URL: \(.url)

Description:
\(.description // "No description")

Suggested Change:
\(.suggestion_content)
"'
            ;;
    esac
}

# Function to delete a suggestion
cmd_delete() {
    local owner="$1"
    local repo="$2"
    local pr_number="$3"
    
    if [ -z "$COMMENT_ID" ]; then
        log_error "Comment ID is required for delete command. Use --comment-id option."
        exit 1
    fi
    
    log_info "Deleting suggestion with comment ID $COMMENT_ID..."
    
    # First, verify the suggestion exists
    local suggestion
    suggestion=$(get_suggestion_by_id "$owner" "$repo" "$pr_number" "$COMMENT_ID")
    
    if [ -z "$suggestion" ] || [ "$suggestion" = "null" ]; then
        log_error "Suggestion with comment ID $COMMENT_ID not found"
        exit 1
    fi
    
    # Show what will be deleted
    echo -e "${YELLOW}About to delete suggestion:${NC}"
    echo "$suggestion" | jq -r '"User: \(.user)
File: \(.path)
Line: \(.line // .position)
Description: \(.description // "No description")
Suggestion: \(.suggestion_content)"'
    
    # Confirm deletion
    if [ "$VERBOSE" = true ]; then
        read -p "Are you sure you want to delete this suggestion? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Deletion cancelled"
            return
        fi
    fi
    
    # Delete the comment
    if gh api "repos/$owner/$repo/pulls/comments/$COMMENT_ID" -X DELETE &> /dev/null; then
        log_success "Suggestion deleted successfully"
    else
        log_error "Failed to delete suggestion. Check permissions and comment ID."
        exit 1
    fi
}

# Function to analyze suggestions
cmd_analyze() {
    local owner="$1"
    local repo="$2"
    local pr_number="$3"
    
    log_info "Analyzing suggestions in PR #$pr_number..."
    
    local suggestions
    suggestions=$(extract_suggestions "$owner" "$repo" "$pr_number")
    
    local analysis
    analysis=$(echo "$suggestions" | jq '{
        total_suggestions: length,
        unique_users: [.[].user] | unique | length,
        files_with_suggestions: [.[].path] | unique | length,
        users: ([.[].user] | group_by(.) | map({user: .[0], count: length})),
        files: ([.[].path] | group_by(.) | map({file: .[0], count: length})),
        suggestions_by_date: ([.[] | .created_at[:10]] | group_by(.) | map({date: .[0], count: length})),
        average_suggestion_length: ([.[].suggestion_content | length] | add / length),
        oldest_suggestion: (.[].created_at | min),
        newest_suggestion: (.[].created_at | max)
    }')
    
    case "$OUTPUT_FORMAT" in
        "json")
            echo "$analysis"
            ;;
        *)
            echo -e "${CYAN}Suggestion Analysis for PR #$pr_number${NC}"
            echo ""
            echo "$analysis" | jq -r '"Total Suggestions: \(.total_suggestions)
Unique Users: \(.unique_users)
Files with Suggestions: \(.files_with_suggestions)
Average Suggestion Length: \(.average_suggestion_length | floor) characters
Date Range: \(.oldest_suggestion[:10]) to \(.newest_suggestion[:10])

Top Contributors:
\(.users | sort_by(-.count) | .[:5][] | "  \(.user): \(.count) suggestion(s)")

Most Suggested Files:
\(.files | sort_by(-.count) | .[:5][] | "  \(.file): \(.count) suggestion(s)")

Suggestions by Date:
\(.suggestions_by_date | sort_by(.date) | .[] | "  \(.date): \(.count) suggestion(s)")
"'
            ;;
    esac
}

# Function to export suggestions
cmd_export() {
    local owner="$1"
    local repo="$2"
    local pr_number="$3"
    
    log_info "Exporting suggestions from PR #$pr_number..."
    
    local suggestions
    suggestions=$(extract_suggestions "$owner" "$repo" "$pr_number")
    
    local output=""
    
    case "$OUTPUT_FORMAT" in
        "json")
            output="$suggestions"
            ;;
        "csv")
            output="ID,User,File,Line,Created,Updated,Description,Suggestion,URL"
            output+="\n"
            output+=$(echo "$suggestions" | jq -r '.[] | [.id, .user, .path, (.line // .position), .created_at, .updated_at, (.description // ""), (.suggestion_content | gsub("\n"; " ")), .url] | @csv')
            ;;
        "markdown")
            output="# GitHub PR Suggestions Export

**Repository:** $owner/$repo  
**Pull Request:** #$pr_number  
**Export Date:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")  
**Total Suggestions:** $(echo "$suggestions" | jq 'length')

"
            output+=$(echo "$suggestions" | jq -r '.[] | "## Suggestion #\(.id)

- **User:** \(.user)
- **File:** \(.path)
- **Line:** \(.line // .position)
- **Created:** \(.created_at)
- **Updated:** \(.updated_at)
- **URL:** \(.url)

### Description
\(.description // "No description provided")

### Suggested Change
```
\(.suggestion_content)
```

---

"')
            ;;
        *)
            output=$(echo "$suggestions" | jq -r '.[] | "Suggestion ID: \(.id)
User: \(.user)
File: \(.path)
Line: \(.line // .position)
Created: \(.created_at)
Description: \(.description // "No description")
Suggestion:
\(.suggestion_content)
URL: \(.url)
═══════════════════════════════════════════════════════════════════════════════════════════════════
"')
            ;;
    esac
    
    if [ -n "$OUTPUT_FILE" ]; then
        echo -e "$output" > "$OUTPUT_FILE"
        log_success "Suggestions exported to $OUTPUT_FILE"
    else
        echo -e "$output"
    fi
}

# Function to show suggestion statistics
cmd_stats() {
    local owner="$1"
    local repo="$2"
    local pr_number="$3"
    
    log_info "Generating suggestion statistics for PR #$pr_number..."
    
    local suggestions
    suggestions=$(extract_suggestions "$owner" "$repo" "$pr_number")
    
    local stats
    stats=$(echo "$suggestions" | jq '{
        total: length,
        users: ([.[].user] | unique | length),
        files: ([.[].path] | unique | length),
        lines_suggested: ([.[].suggestion_content | split("\n") | length] | add),
        avg_lines_per_suggestion: ([.[].suggestion_content | split("\n") | length] | add / length),
        with_description: ([.[] | select(.description != "")] | length),
        without_description: ([.[] | select(.description == "")] | length)
    }')
    
    echo -e "${CYAN}Suggestion Statistics for PR #$pr_number${NC}"
    echo ""
    echo "$stats" | jq -r '"📊 Overview:
   Total Suggestions: \(.total)
   Unique Contributors: \(.users)
   Files Affected: \(.files)
   
📝 Content Analysis:
   Total Lines Suggested: \(.lines_suggested)
   Average Lines per Suggestion: \(.avg_lines_per_suggestion | floor)
   With Description: \(.with_description)
   Without Description: \(.without_description)
   
📈 Quality Metrics:
   Description Rate: \((.with_description / .total * 100) | floor)%
   Files per Suggestion: \(.files / .total | floor)
"'
}

# Function to parse command line arguments
parse_args() {
    if [ $# -lt 4 ]; then
        log_error "Invalid number of arguments"
        usage
    fi
    
    COMMAND="$1"
    OWNER="$2"
    REPO="$3"
    PR_NUMBER="$4"
    shift 4
    
    while [ $# -gt 0 ]; do
        case "$1" in
            --comment-id)
                shift
                COMMENT_ID="$1"
                ;;
            --output)
                shift
                OUTPUT_FORMAT="$1"
                ;;
            --format)
                shift
                OUTPUT_FORMAT="$1"
                ;;
            --file)
                shift
                OUTPUT_FILE="$1"
                ;;
            --verbose)
                VERBOSE=true
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
        shift
    done
    
    # Validate command
    case "$COMMAND" in
        list|show|delete|analyze|export|stats)
            ;;
        *)
            log_error "Invalid command: $COMMAND"
            usage
            ;;
    esac
    
    # Validate PR number
    if [[ ! "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
        log_error "PR number must be a positive integer"
        exit 1
    fi
    
    # Validate output format
    case "$OUTPUT_FORMAT" in
        human|json|csv|markdown)
            ;;
        *)
            log_error "Invalid output format: $OUTPUT_FORMAT"
            echo "Supported formats: human, json, csv, markdown"
            exit 1
            ;;
    esac
}

# Main function
main() {
    parse_args "$@"
    
    # Check dependencies and authentication
    check_dependencies
    check_auth
    
    # Validate PR exists
    validate_pr "$OWNER" "$REPO" "$PR_NUMBER"
    
    # Execute command
    case "$COMMAND" in
        list)
            cmd_list "$OWNER" "$REPO" "$PR_NUMBER"
            ;;
        show)
            cmd_show "$OWNER" "$REPO" "$PR_NUMBER"
            ;;
        delete)
            cmd_delete "$OWNER" "$REPO" "$PR_NUMBER"
            ;;
        analyze)
            cmd_analyze "$OWNER" "$REPO" "$PR_NUMBER"
            ;;
        export)
            cmd_export "$OWNER" "$REPO" "$PR_NUMBER"
            ;;
        stats)
            cmd_stats "$OWNER" "$REPO" "$PR_NUMBER"
            ;;
    esac
}

# Run main function with all arguments
main "$@"