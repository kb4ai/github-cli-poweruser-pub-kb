#!/bin/bash

# Reply to GitHub PR Review Comment
# ⚠️  CRITICAL: This script CREATES NEW REPLY COMMENTS (does NOT edit existing ones)
# Usage: ./reply-to-comment.sh OWNER REPO PR_NUMBER COMMENT_ID "Reply message"

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo
    echo "🆕 CRITICAL: This script CREATES NEW REPLY COMMENTS (NOT edits)"
    echo "============================================================"
    echo "Usage: $0 OWNER REPO PR_NUMBER COMMENT_ID 'Reply message'"
    echo
    echo "EDIT vs REPLY:"
    echo "  • EDIT: Modifies existing comment content (use edit-comment.sh)"
    echo "  • REPLY: Creates new comment in thread (this script)"
    echo
    echo "Example:"
    echo "  $0 FlowCortex flowcortex 107 2172519617 'Thanks for the feedback!'"
    echo
    echo "THREADING BEHAVIOR:"
    echo "  • Creates NEW comment with unique ID"
    echo "  • Forms conversation thread with original comment"
    echo "  • Triggers notifications to all thread participants"
    echo "  • Becomes permanent part of PR conversation history"
    echo
    echo "PERMISSIONS REQUIRED:"
    echo "  • Any collaborator with repository access can reply"
    echo "  • No need to be the original comment author"
    echo
    echo "For editing existing comments, use: ./edit-comment.sh OWNER REPO COMMENT_ID 'New content'"
    echo
    exit 1
}

# Validate input parameters
if [ $# -ne 5 ]; then
    echo -e "${RED}Error: Invalid number of arguments${NC}"
    usage
fi

OWNER="$1"
REPO="$2"
PR_NUMBER="$3"
COMMENT_ID="$4"
REPLY_MESSAGE="$5"

# Validate PR number is numeric
if ! [[ "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Error: PR_NUMBER must be a number${NC}"
    exit 1
fi

# Validate comment ID is numeric
if ! [[ "$COMMENT_ID" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Error: COMMENT_ID must be a number${NC}"
    exit 1
fi

echo -e "${BLUE}🆕 CREATING NEW REPLY to comment ID ${COMMENT_ID} on PR #${PR_NUMBER} in ${OWNER}/${REPO}...${NC}"
echo -e "${YELLOW}⚠️  This will CREATE a new comment in the conversation thread${NC}"
echo

# Check if GitHub CLI is authenticated
if ! gh auth status >/dev/null 2>&1; then
    echo -e "${RED}Error: GitHub CLI not authenticated. Run 'gh auth login' first.${NC}"
    exit 1
fi

# Validate comment exists
echo -e "${YELLOW}Validating comment exists...${NC}"
if ! comment_data=$(gh api repos/"$OWNER"/"$REPO"/pulls/comments/"$COMMENT_ID" 2>/dev/null); then
    echo -e "${RED}Error: Comment ID ${COMMENT_ID} not found${NC}"
    exit 1
fi

# Display original comment info
echo -e "${GREEN}📋 ORIGINAL COMMENT (you are replying to):${NC}"
echo "$comment_data" | jq -r '
    "📍 File: \(.path // "general"):\(.line // "N/A")
    👤 Author: \(.user.login)
    🆔 Comment ID: \(.id)
    💬 Original: \(.body)
    📅 Created: \(.created_at)
    🔗 URL: \(.html_url)"
'

echo -e "${BLUE}📝 YOUR REPLY WILL BE:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "$REPLY_MESSAGE"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

# Safety confirmation
echo -e "${YELLOW}⚠️  SAFETY CONFIRMATION${NC}"
echo -e "${YELLOW}This will create a new reply comment that:${NC}"
echo -e "${YELLOW}  • Becomes permanent part of PR conversation${NC}"
echo -e "${YELLOW}  • Triggers notifications to thread participants${NC}"
echo -e "${YELLOW}  • Creates a new comment with its own ID${NC}"
echo -e "${YELLOW}  • Cannot be undone (only deleted after creation)${NC}"
echo
echo -n "Proceed with creating this reply? (y/N): "
read -r confirm
if [ "$confirm" != "y" ]; then
    echo -e "${YELLOW}❌ Reply cancelled by user${NC}"
    exit 0
fi

# Post reply using the REST API endpoint for replies
echo -e "${YELLOW}🚀 Posting reply...${NC}"
if response=$(gh api repos/"$OWNER"/"$REPO"/pulls/"$PR_NUMBER"/comments/"$COMMENT_ID"/replies \
  -X POST \
  -f body="$REPLY_MESSAGE" 2>/dev/null); then
    
    echo -e "${GREEN}✅ Reply posted successfully!${NC}"
    echo
    echo -e "${GREEN}📊 REPLY SUMMARY:${NC}"
    echo "Reply ID: $(echo "$response" | jq -r '.id')"
    echo "In reply to: $(echo "$response" | jq -r '.in_reply_to_id')"
    echo "Reply URL: $(echo "$response" | jq -r '.html_url')"
    echo "Created at: $(echo "$response" | jq -r '.created_at')"
    echo
    echo -e "${BLUE}💡 This reply is now part of the conversation thread${NC}"
else
    echo -e "${RED}Error: Failed to post reply. This might be due to:${NC}"
    echo "  - Insufficient permissions"
    echo "  - Comment thread is locked"
    echo "  - Repository restrictions"
    exit 1
fi

echo
echo -e "${BLUE}🎉 Reply operation completed successfully!${NC}"
echo -e "${BLUE}Your reply has been added to the conversation thread.${NC}"