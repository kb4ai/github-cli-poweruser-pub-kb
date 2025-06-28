#!/bin/bash

# create-suggestion.sh - Create GitHub PR suggested changes via API
# 
# This script creates suggested changes on GitHub Pull Request review comments
# using the GitHub REST API. Supports both single-line and multi-line suggestions.
#
# Usage: ./create-suggestion.sh OWNER REPO PR_NUMBER FILE_PATH LINE_NUMBER SUGGESTION_TEXT [DESCRIPTION]
#
# Arguments:
#   OWNER          - Repository owner (user or organization)
#   REPO           - Repository name
#   PR_NUMBER      - Pull request number
#   FILE_PATH      - Path to file in the repository
#   LINE_NUMBER    - Line number in the diff (or start line for multi-line)
#   SUGGESTION_TEXT - The suggested code change
#   DESCRIPTION    - Optional description of the suggestion
#
# Examples:
#   # Single line suggestion
#   ./create-suggestion.sh octocat Hello-World 123 "src/main.js" 45 "console.log('fixed');" "Fix console message"
#
#   # Multi-line suggestion (use \n for line breaks)
#   ./create-suggestion.sh octocat Hello-World 123 "README.md" 10 "# New Title\nThis is better content" "Improve documentation"
#
# Requirements:
#   - GitHub CLI (gh) installed and authenticated
#   - jq for JSON processing
#   - Write permissions to the repository

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo "Usage: $0 OWNER REPO PR_NUMBER FILE_PATH LINE_NUMBER SUGGESTION_TEXT [DESCRIPTION]"
    echo ""
    echo "Arguments:"
    echo "  OWNER          Repository owner (user or organization)"
    echo "  REPO           Repository name"
    echo "  PR_NUMBER      Pull request number"
    echo "  FILE_PATH      Path to file in the repository"
    echo "  LINE_NUMBER    Line number in the diff"
    echo "  SUGGESTION_TEXT The suggested code change"
    echo "  DESCRIPTION    Optional description of the suggestion"
    echo ""
    echo "Examples:"
    echo "  # Single line suggestion"
    echo "  $0 octocat Hello-World 123 \"src/main.js\" 45 \"console.log('fixed');\" \"Fix console message\""
    echo ""
    echo "  # Multi-line suggestion (use \\n for line breaks)"
    echo "  $0 octocat Hello-World 123 \"README.md\" 10 \"# New Title\\nThis is better content\" \"Improve documentation\""
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
    
    log_info "Validating PR #$pr_number in $owner/$repo..."
    
    if ! gh api "repos/$owner/$repo/pulls/$pr_number" &> /dev/null; then
        log_error "PR #$pr_number not found in repository $owner/$repo"
        exit 1
    fi
    
    log_success "PR #$pr_number found"
}

# Function to get the commit SHA for the PR head
get_pr_head_sha() {
    local owner="$1"
    local repo="$2"
    local pr_number="$3"
    
    gh api "repos/$owner/$repo/pulls/$pr_number" --jq '.head.sha'
}

# Function to get the diff position for a line number
get_diff_position() {
    local owner="$1"
    local repo="$2"
    local pr_number="$3"
    local file_path="$4"
    local line_number="$5"
    
    log_info "Getting diff position for line $line_number in $file_path..."
    
    # Get the PR diff
    local diff_response
    diff_response=$(gh api "repos/$owner/$repo/pulls/$pr_number" -H "Accept: application/vnd.github.v3.diff" 2>/dev/null)
    
    if [ -z "$diff_response" ]; then
        log_error "Could not retrieve diff for PR #$pr_number"
        return 1
    fi
    
    # Parse diff to find position
    # This is a simplified approach - in practice, you'd need more sophisticated diff parsing
    # For now, we'll use the line number as a rough estimate
    echo "$line_number"
}

# Function to create suggestion comment
create_suggestion_comment() {
    local owner="$1"
    local repo="$2"
    local pr_number="$3"
    local file_path="$4"
    local line_number="$5"
    local suggestion_text="$6"
    local description="$7"
    
    log_info "Creating suggestion comment..."
    
    # Get PR head SHA
    local commit_sha
    commit_sha=$(get_pr_head_sha "$owner" "$repo" "$pr_number")
    
    if [ -z "$commit_sha" ]; then
        log_error "Could not get commit SHA for PR head"
        exit 1
    fi
    
    # Get diff position
    local position
    position=$(get_diff_position "$owner" "$repo" "$pr_number" "$file_path" "$line_number")
    
    if [ -z "$position" ]; then
        log_error "Could not determine diff position"
        exit 1
    fi
    
    # Build the comment body with suggestion block
    local comment_body=""
    
    # Add description if provided
    if [ -n "$description" ]; then
        comment_body="$description\n\n"
    fi
    
    # Add suggestion block
    comment_body="${comment_body}\`\`\`suggestion\n$suggestion_text\n\`\`\`"
    
    # Create the review comment
    local response
    response=$(gh api "repos/$owner/$repo/pulls/$pr_number/comments" \
        -X POST \
        -f body="$comment_body" \
        -f commit_id="$commit_sha" \
        -f path="$file_path" \
        -F position="$position" \
        --jq '.id' 2>/dev/null)
    
    if [ -n "$response" ]; then
        log_success "Suggestion comment created with ID: $response"
        echo "Comment URL: https://github.com/$owner/$repo/pull/$pr_number#issuecomment-$response"
        return 0
    else
        log_error "Failed to create suggestion comment"
        return 1
    fi
}

# Function to create suggestion via review (alternative method)
create_suggestion_via_review() {
    local owner="$1"
    local repo="$2"
    local pr_number="$3"
    local file_path="$4"
    local line_number="$5"
    local suggestion_text="$6"
    local description="$7"
    
    log_info "Creating suggestion via review (alternative method)..."
    
    # Get PR head SHA
    local commit_sha
    commit_sha=$(get_pr_head_sha "$owner" "$repo" "$pr_number")
    
    if [ -z "$commit_sha" ]; then
        log_error "Could not get commit SHA for PR head"
        exit 1
    fi
    
    # Build the comment body with suggestion block
    local comment_body=""
    
    # Add description if provided
    if [ -n "$description" ]; then
        comment_body="$description\n\n"
    fi
    
    # Add suggestion block
    comment_body="${comment_body}\`\`\`suggestion\n$suggestion_text\n\`\`\`"
    
    # Create review with suggestion comment
    local review_body='{
        "commit_id": "'$commit_sha'",
        "body": "Code suggestion",
        "event": "COMMENT",
        "comments": [
            {
                "path": "'$file_path'",
                "position": '$line_number',
                "body": "'$(echo "$comment_body" | sed 's/"/\\"/g' | sed 's/\n/\\n/g')'"
            }
        ]
    }'
    
    local response
    response=$(gh api "repos/$owner/$repo/pulls/$pr_number/reviews" \
        -X POST \
        --input - <<< "$review_body" \
        --jq '.id' 2>/dev/null)
    
    if [ -n "$response" ]; then
        log_success "Suggestion review created with ID: $response"
        echo "Review URL: https://github.com/$owner/$repo/pull/$pr_number#pullrequestreview-$response"
        return 0
    else
        log_error "Failed to create suggestion review"
        return 1
    fi
}

# Main function
main() {
    # Check arguments
    if [ $# -lt 6 ] || [ $# -gt 7 ]; then
        log_error "Invalid number of arguments"
        usage
    fi
    
    local owner="$1"
    local repo="$2"
    local pr_number="$3"
    local file_path="$4"
    local line_number="$5"
    local suggestion_text="$6"
    local description="${7:-}"
    
    # Validate inputs
    if [[ ! "$pr_number" =~ ^[0-9]+$ ]]; then
        log_error "PR number must be a positive integer"
        exit 1
    fi
    
    if [[ ! "$line_number" =~ ^[0-9]+$ ]]; then
        log_error "Line number must be a positive integer"
        exit 1
    fi
    
    # Check dependencies and authentication
    check_dependencies
    check_auth
    
    # Validate PR exists
    validate_pr "$owner" "$repo" "$pr_number"
    
    # Process multi-line suggestions (replace \n with actual newlines)
    suggestion_text=$(echo -e "$suggestion_text")
    
    log_info "Creating suggestion for:"
    echo "  Repository: $owner/$repo"
    echo "  PR: #$pr_number"
    echo "  File: $file_path"
    echo "  Line: $line_number"
    echo "  Description: ${description:-"(none)"}"
    echo "  Suggestion:"
    echo "    $(echo "$suggestion_text" | head -3)"
    if [ "$(echo "$suggestion_text" | wc -l)" -gt 3 ]; then
        echo "    ... ($(echo "$suggestion_text" | wc -l) lines total)"
    fi
    echo ""
    
    # Try creating suggestion comment first
    if create_suggestion_comment "$owner" "$repo" "$pr_number" "$file_path" "$line_number" "$suggestion_text" "$description"; then
        log_success "Suggestion created successfully!"
    else
        log_warning "Direct comment creation failed, trying review method..."
        if create_suggestion_via_review "$owner" "$repo" "$pr_number" "$file_path" "$line_number" "$suggestion_text" "$description"; then
            log_success "Suggestion created successfully via review!"
        else
            log_error "Failed to create suggestion using both methods"
            exit 1
        fi
    fi
}

# Run main function with all arguments
main "$@"