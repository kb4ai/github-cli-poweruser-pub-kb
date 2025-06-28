#!/bin/bash

# Basic GitHub PR Review Comments Reader
# Usage: ./basic-comment-reader.sh OWNER REPO PR_NUMBER

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo "Usage: $0 OWNER REPO PR_NUMBER"
    echo "Example: $0 octocat Hello-World 37"
    exit 1
}

# Validate input parameters
if [ $# -ne 3 ]; then
    echo -e "${RED}Error: Invalid number of arguments${NC}"
    usage
fi

OWNER="$1"
REPO="$2"
PR_NUMBER="$3"

# Validate PR number is numeric
if ! [[ "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Error: PR_NUMBER must be a number${NC}"
    exit 1
fi

echo -e "${BLUE}Fetching review comments for PR #${PR_NUMBER} in ${OWNER}/${REPO}...${NC}"

# Check if GitHub CLI is authenticated
if ! gh auth status >/dev/null 2>&1; then
    echo -e "${RED}Error: GitHub CLI not authenticated. Run 'gh auth login' first.${NC}"
    exit 1
fi

# Check if PR exists
if ! gh api repos/"$OWNER"/"$REPO"/pulls/"$PR_NUMBER" >/dev/null 2>&1; then
    echo -e "${RED}Error: PR #${PR_NUMBER} not found in ${OWNER}/${REPO}${NC}"
    exit 1
fi

# Fetch review comments
echo -e "${YELLOW}Fetching review comments (inline comments)...${NC}"
review_comments=$(gh api --paginate repos/"$OWNER"/"$REPO"/pulls/"$PR_NUMBER"/comments 2>/dev/null)

# Check if any review comments exist
if [ "$review_comments" = "[]" ] || [ -z "$review_comments" ]; then
    echo -e "${YELLOW}No review comments found for this PR.${NC}"
else
    # Count and display review comments
    comment_count=$(echo "$review_comments" | jq '. | length')
    echo -e "${GREEN}Found ${comment_count} review comment(s):${NC}"
    echo
    
    # Display formatted review comments
    echo "$review_comments" | jq -r '
        .[] | 
        "📍 \(.path):\(.line // "general")
        👤 \(.user.login) (\(.author_association))
        💬 \(.body)
        📅 \(.created_at)
        🔗 \(.html_url)
        " + (if .in_reply_to_id then "↪️  Reply to comment ID: \(.in_reply_to_id)" else "" end) + "
        " + "─" * 80
    '
fi

# Also fetch general PR comments (issue comments)
echo -e "${YELLOW}Fetching general PR comments...${NC}"
issue_comments=$(gh api --paginate repos/"$OWNER"/"$REPO"/issues/"$PR_NUMBER"/comments 2>/dev/null)

if [ "$issue_comments" = "[]" ] || [ -z "$issue_comments" ]; then
    echo -e "${YELLOW}No general PR comments found.${NC}"
else
    # Count and display issue comments
    issue_comment_count=$(echo "$issue_comments" | jq '. | length')
    echo -e "${GREEN}Found ${issue_comment_count} general comment(s):${NC}"
    echo
    
    # Display formatted issue comments
    echo "$issue_comments" | jq -r '
        .[] | 
        "💬 General Comment
        👤 \(.user.login) (\(.author_association))
        📝 \(.body)
        📅 \(.created_at)
        🔗 \(.html_url)
        " + "─" * 80
    '
fi

# Summary
total_review_comments=$(echo "$review_comments" | jq '. | length' 2>/dev/null || echo "0")
total_issue_comments=$(echo "$issue_comments" | jq '. | length' 2>/dev/null || echo "0")
total_comments=$((total_review_comments + total_issue_comments))

echo
echo -e "${BLUE}Summary for PR #${PR_NUMBER}:${NC}"
echo -e "  Review comments (inline): ${total_review_comments}"
echo -e "  General comments: ${total_issue_comments}"
echo -e "  Total comments: ${total_comments}"