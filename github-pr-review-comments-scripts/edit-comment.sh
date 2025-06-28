#!/bin/bash

# Edit GitHub PR Review Comment
# CRITICAL: This script EDITS existing comment content (does NOT create replies)
# Usage: ./edit-comment.sh OWNER REPO COMMENT_ID "New content"

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo
    echo "🚨 CRITICAL: This script EDITS existing comment content (NOT replies)"
    echo "================================================================="
    echo "Usage: $0 OWNER REPO COMMENT_ID 'New content'"
    echo
    echo "EDIT vs REPLY:"
    echo "  • EDIT: Modifies existing comment content (this script)"
    echo "  • REPLY: Creates new comment in thread (use reply-to-comment.sh)"
    echo
    echo "Example:"
    echo "  $0 octocat Hello-World 123456789 'Updated: Fixed the typo in variable name'"
    echo
    echo "SAFETY REQUIREMENTS:"
    echo "  • You must be the comment author OR repository admin"
    echo "  • Original content will be REPLACED (edit history preserved)"
    echo "  • This operation modifies existing comment, not creates new one"
    echo
    echo "For replies, use: ./reply-to-comment.sh OWNER REPO PR_NUMBER COMMENT_ID 'Reply'"
    echo
    exit 1
}

# Function to check if user can edit comment
check_edit_permission() {
    local comment_id="$1"
    local current_user=$(gh api user --jq '.login' 2>/dev/null)
    
    if [ -z "$current_user" ]; then
        echo -e "${RED}❌ Error: Could not determine current user${NC}"
        return 1
    fi
    
    # Get comment author
    local comment_author=$(gh api repos/"$OWNER"/"$REPO"/pulls/comments/"$comment_id" --jq '.user.login' 2>/dev/null)
    
    if [ -z "$comment_author" ]; then
        echo -e "${RED}❌ Error: Could not retrieve comment author${NC}"
        return 1
    fi
    
    if [ "$current_user" = "$comment_author" ]; then
        echo -e "${GREEN}✅ Permission verified: You are the comment author${NC}"
        return 0
    fi
    
    # Check if user has admin access
    local user_permission=$(gh api repos/"$OWNER"/"$REPO"/collaborators/"$current_user"/permission --jq '.permission' 2>/dev/null)
    if [ "$user_permission" = "admin" ] || [ "$user_permission" = "maintain" ]; then
        echo -e "${GREEN}✅ Permission verified: You have admin/maintain access${NC}"
        return 0
    fi
    
    echo -e "${RED}❌ Permission denied: You can only edit your own comments or need admin access${NC}"
    echo -e "${YELLOW}💡 Current user: $current_user${NC}"
    echo -e "${YELLOW}💡 Comment author: $comment_author${NC}"
    return 1
}

# Function to display comment details
show_comment_details() {
    local comment_data="$1"
    
    echo -e "${CYAN}📋 ORIGINAL COMMENT DETAILS:${NC}"
    echo "$comment_data" | jq -r '
        "📍 File: \(.path // "general"):\(.line // "N/A")
        👤 Author: \(.user.login)
        🆔 Comment ID: \(.id)
        📅 Created: \(.created_at)
        ✏️  Last edited: \(.updated_at)
        🔗 URL: \(.html_url)
        
        💬 CURRENT CONTENT:
        \(.body)
        "
    '
}

# Validate input parameters
if [ $# -ne 4 ]; then
    echo -e "${RED}❌ Error: Invalid number of arguments${NC}"
    usage
fi

OWNER="$1"
REPO="$2"
COMMENT_ID="$3"
NEW_CONTENT="$4"

# Validate comment ID is numeric
if ! [[ "$COMMENT_ID" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}❌ Error: COMMENT_ID must be a number${NC}"
    exit 1
fi

# Validate new content is not empty
if [ -z "$NEW_CONTENT" ]; then
    echo -e "${RED}❌ Error: New content cannot be empty${NC}"
    exit 1
fi

echo -e "${BLUE}🔄 EDITING comment ID ${COMMENT_ID} in ${OWNER}/${REPO}...${NC}"
echo -e "${YELLOW}⚠️  WARNING: This will MODIFY existing comment content!${NC}"
echo

# Check if GitHub CLI is authenticated
if ! gh auth status >/dev/null 2>&1; then
    echo -e "${RED}❌ Error: GitHub CLI not authenticated. Run 'gh auth login' first.${NC}"
    exit 1
fi

# Validate comment exists and get details
echo -e "${YELLOW}🔍 Validating comment exists...${NC}"
if ! comment_data=$(gh api repos/"$OWNER"/"$REPO"/pulls/comments/"$COMMENT_ID" 2>/dev/null); then
    echo -e "${RED}❌ Error: Comment ID ${COMMENT_ID} not found in ${OWNER}/${REPO}${NC}"
    echo -e "${YELLOW}💡 Tip: Use 'gh api repos/$OWNER/$REPO/pulls/PR_NUMBER/comments' to list comments${NC}"
    exit 1
fi

# Display original comment details
show_comment_details "$comment_data"

# Check edit permissions
echo -e "${YELLOW}🔐 Checking edit permissions...${NC}"
if ! check_edit_permission "$COMMENT_ID"; then
    echo -e "${RED}❌ SAFETY BLOCK: Operation cancelled due to insufficient permissions${NC}"
    echo -e "${YELLOW}💡 You can only edit your own comments or need admin access${NC}"
    echo -e "${YELLOW}💡 To reply instead, use: ./reply-to-comment.sh $OWNER $REPO PR_NUMBER $COMMENT_ID 'Reply text'${NC}"
    exit 1
fi

# Show new content
echo -e "${CYAN}📝 NEW CONTENT TO BE SAVED:${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "$NEW_CONTENT"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

# Safety confirmation
echo -e "${YELLOW}⚠️  SAFETY CONFIRMATION REQUIRED${NC}"
echo -e "${YELLOW}This will REPLACE the existing comment content permanently.${NC}"
echo -e "${YELLOW}The original content will be preserved in edit history.${NC}"
echo
echo -e "${YELLOW}Do you want to proceed with editing this comment?${NC}"
echo -n "Type 'yes' to confirm, or anything else to cancel: "
read -r confirm

if [ "$confirm" != "yes" ]; then
    echo -e "${YELLOW}❌ Edit operation cancelled by user${NC}"
    exit 0
fi

# Perform the edit
echo -e "${YELLOW}💾 Saving updated comment...${NC}"
if response=$(gh api repos/"$OWNER"/"$REPO"/pulls/comments/"$COMMENT_ID" \
  -X PATCH \
  -f body="$NEW_CONTENT" 2>/dev/null); then
    
    echo -e "${GREEN}✅ Comment edited successfully!${NC}"
    echo
    echo -e "${GREEN}📊 EDIT SUMMARY:${NC}"
    echo "Comment ID: $(echo "$response" | jq -r '.id')"
    echo "Updated at: $(echo "$response" | jq -r '.updated_at')"
    echo "View comment: $(echo "$response" | jq -r '.html_url')"
    echo
    echo -e "${BLUE}💡 The edit history is preserved and visible in GitHub UI${NC}"
    
else
    echo -e "${RED}❌ Error: Failed to edit comment. This might be due to:${NC}"
    echo -e "${RED}  • Insufficient permissions (you must be author or admin)${NC}"
    echo -e "${RED}  • Comment is in a locked conversation${NC}"
    echo -e "${RED}  • Repository access restrictions${NC}"
    echo -e "${RED}  • Network connectivity issues${NC}"
    echo
    echo -e "${YELLOW}💡 Troubleshooting steps:${NC}"
    echo -e "${YELLOW}  1. Verify you're the comment author: gh api repos/$OWNER/$REPO/pulls/comments/$COMMENT_ID --jq '.user.login'${NC}"
    echo -e "${YELLOW}  2. Check your authentication: gh auth status${NC}"
    echo -e "${YELLOW}  3. Try viewing the comment: gh api repos/$OWNER/$REPO/pulls/comments/$COMMENT_ID${NC}"
    exit 1
fi

echo
echo -e "${BLUE}🎉 Edit operation completed successfully!${NC}"
echo -e "${BLUE}The comment has been updated with your new content.${NC}"