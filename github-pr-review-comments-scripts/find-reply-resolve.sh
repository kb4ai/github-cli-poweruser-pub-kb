#!/bin/bash

# Find, Reply to, and Resolve GitHub PR Review Comments
# Usage: ./find-reply-resolve.sh OWNER REPO PR_NUMBER SEARCH_TEXT "Reply message"

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
    echo "🆕 CREATES REPLY COMMENTS: This script does NOT edit existing comments"
    echo "========================================================================="
    echo "Usage: $0 OWNER REPO PR_NUMBER SEARCH_TEXT 'Reply message'"
    echo "Example: $0 FlowCortex flowcortex 107 'FOO_BAR_TEST' 'Issue addressed, marking as resolved'"
    echo
    echo "OPERATION TYPE: REPLY (Creates new comments in threads)"
    echo
    echo "This script will:"
    echo "1. Find all review comments containing SEARCH_TEXT"
    echo "2. REPLY to each matching comment (creates NEW comments)"
    echo "3. Resolve the conversation thread"
    echo
    echo "⚠️  SAFETY WARNING:"
    echo "  • Creates NEW reply comments (does not modify existing)"
    echo "  • Triggers notifications to all thread participants"
    echo "  • Replies become permanent part of conversation history"
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
SEARCH_TEXT="$4"
REPLY_MESSAGE="$5"

# Validate PR number is numeric
if ! [[ "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Error: PR_NUMBER must be a number${NC}"
    exit 1
fi

echo -e "${BLUE}Processing PR #${PR_NUMBER} in ${OWNER}/${REPO}${NC}"
echo -e "${BLUE}Searching for comments containing: '${SEARCH_TEXT}'${NC}"
echo

# Check if GitHub CLI is authenticated
if ! gh auth status >/dev/null 2>&1; then
    echo -e "${RED}Error: GitHub CLI not authenticated. Run 'gh auth login' first.${NC}"
    exit 1
fi

# Step 1: Find comments containing the search text
echo -e "${YELLOW}Step 1: Finding comments containing '${SEARCH_TEXT}'...${NC}"

matching_comments=$(gh api repos/"$OWNER"/"$REPO"/pulls/"$PR_NUMBER"/comments | \
  jq --arg search "$SEARCH_TEXT" '.[] | select(.body | contains($search)) | {id, body, user: .user.login, path, line, html_url}')

# CRITICAL SAFETY CHECK: Ensure matching_comments is not empty/null and contains valid JSON
if [ -z "$matching_comments" ] || [ "$matching_comments" = "" ] || [ "$matching_comments" = "null" ]; then
    echo -e "${YELLOW}No comments found containing '${SEARCH_TEXT}'${NC}"
    echo -e "${RED}SAFETY EXIT: No target comments found - script will not process any comments${NC}"
    exit 0
fi

# Additional safety check: verify we have valid JSON with at least one comment
if ! echo "$matching_comments" | jq -e '.' >/dev/null 2>&1; then
    echo -e "${RED}ERROR: Invalid JSON response from comment search${NC}"
    echo -e "${RED}SAFETY EXIT: Cannot safely parse comment data${NC}"
    exit 1
fi

# Count matching comments
comment_count=$(echo "$matching_comments" | jq -s '. | length')
echo -e "${GREEN}Found ${comment_count} matching comment(s):${NC}"
echo

# Display matching comments
echo "$matching_comments" | jq -s -r '.[] | 
    "📍 Comment ID: \(.id)
    👤 Author: \(.user)
    📂 File: \(.path // "general"):\(.line // "N/A")  
    💬 Content: \(.body)
    🔗 URL: \(.html_url)
    " + "─" * 80'

echo
echo -e "${BLUE}Processing ${comment_count} comment(s)...${NC}"

# Step 2: Process each matching comment
# CRITICAL SAFETY CHECK: Extract comment IDs with validation
comment_ids_raw=$(echo "$matching_comments" | jq -s -r '.[].id // empty')

if [ -z "$comment_ids_raw" ]; then
    echo -e "${RED}CRITICAL ERROR: No valid comment IDs found in matching results${NC}"
    echo -e "${RED}SAFETY EXIT: Cannot proceed without valid comment IDs${NC}"
    exit 1
fi

# Convert to array only after validation
readarray -t comment_ids <<< "$comment_ids_raw"

# Final safety check: ensure we have actual comment IDs
if [ ${#comment_ids[@]} -eq 0 ]; then
    echo -e "${RED}CRITICAL ERROR: Comment IDs array is empty${NC}"
    echo -e "${RED}SAFETY EXIT: No comments to process${NC}"
    exit 1
fi

echo -e "${BLUE}SAFETY VALIDATION PASSED: Processing ${#comment_ids[@]} validated comment(s)${NC}"

for comment_id in "${comment_ids[@]}"; do
    echo
    echo -e "${YELLOW}Processing comment ID: ${comment_id}${NC}"
    
    # CRITICAL SAFETY CHECK: Validate comment ID is numeric and not empty
    if [ -z "$comment_id" ] || ! [[ "$comment_id" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}ERROR: Invalid comment ID '${comment_id}' - skipping${NC}"
        continue
    fi
    
    # CRITICAL SAFETY CHECK: Verify comment still exists and matches our search
    echo -e "  → Validating comment exists and matches search criteria..."
    if ! comment_validation=$(gh api repos/"$OWNER"/"$REPO"/pulls/comments/"$comment_id" 2>/dev/null); then
        echo -e "    ${RED}❌ Comment ${comment_id} no longer exists - skipping${NC}"
        continue
    fi
    
    # Verify this comment actually contains our search text
    comment_body=$(echo "$comment_validation" | jq -r '.body // ""')
    if [[ "$comment_body" != *"$SEARCH_TEXT"* ]]; then
        echo -e "    ${RED}❌ Comment ${comment_id} does not contain '${SEARCH_TEXT}' - SAFETY ABORT${NC}"
        echo -e "    ${RED}This indicates a critical bug - stopping all processing${NC}"
        exit 1
    fi
    
    echo -e "    ${GREEN}✅ Comment validated - contains target text '${SEARCH_TEXT}'${NC}"
    
    # Step 2a: Post reply
    echo -e "  → Posting reply..."
    
    if reply_response=$(gh api repos/"$OWNER"/"$REPO"/pulls/"$PR_NUMBER"/comments/"$comment_id"/replies \
      -X POST \
      -f body="$REPLY_MESSAGE" 2>/dev/null); then
        
        reply_id=$(echo "$reply_response" | jq -r '.id')
        reply_url=$(echo "$reply_response" | jq -r '.html_url')
        echo -e "    ${GREEN}✅ Reply posted successfully (ID: ${reply_id})${NC}"
        echo -e "    🔗 ${reply_url}"
    else
        echo -e "    ${RED}❌ Failed to post reply${NC}"
        echo -e "    ${YELLOW}Continuing with resolution attempt...${NC}"
    fi
    
    # Step 2b: Resolve conversation thread
    echo -e "  → Resolving conversation thread..."
    
    # Get review threads to find the thread ID
    graphql_query='
    query($owner: String!, $name: String!, $number: Int!) {
      repository(owner: $owner, name: $name) {
        pullRequest(number: $number) {
          reviewThreads(first: 100) {
            nodes {
              id
              isResolved
              comments(first: 100) {
                nodes {
                  databaseId
                }
              }
            }
          }
        }
      }
    }'
    
    if review_threads=$(gh api graphql \
      -f query="$graphql_query" \
      -F owner="$OWNER" \
      -F name="$REPO" \
      -F number="$PR_NUMBER" 2>/dev/null); then
        
        # Find the thread ID for this comment
        thread_id=$(echo "$review_threads" | jq -r --arg comment_id "$comment_id" '
          .data.repository.pullRequest.reviewThreads.nodes[] | 
          select(.comments.nodes[] | .databaseId == ($comment_id | tonumber)) | 
          .id
        ')
        
        if [ -n "$thread_id" ] && [ "$thread_id" != "null" ]; then
            # Check if already resolved
            thread_resolved=$(echo "$review_threads" | jq -r --arg comment_id "$comment_id" '
              .data.repository.pullRequest.reviewThreads.nodes[] | 
              select(.comments.nodes[] | .databaseId == ($comment_id | tonumber)) | 
              .isResolved
            ')
            
            if [ "$thread_resolved" = "true" ]; then
                echo -e "    ${YELLOW}⚠️  Thread already resolved${NC}"
            else
                # Resolve the thread
                resolve_mutation='
                mutation($threadId: ID!) {
                  resolveReviewThread(input: {threadId: $threadId}) {
                    thread {
                      id
                      isResolved
                    }
                  }
                }'
                
                if resolve_result=$(gh api graphql \
                  -f query="$resolve_mutation" \
                  -f threadId="$thread_id" 2>/dev/null); then
                    
                    resolved_status=$(echo "$resolve_result" | jq -r '.data.resolveReviewThread.thread.isResolved')
                    
                    if [ "$resolved_status" = "true" ]; then
                        echo -e "    ${GREEN}✅ Conversation resolved successfully${NC}"
                    else
                        echo -e "    ${RED}❌ Failed to resolve conversation${NC}"
                    fi
                else
                    echo -e "    ${RED}❌ GraphQL mutation failed (insufficient permissions?)${NC}"
                fi
            fi
        else
            echo -e "    ${YELLOW}⚠️  Could not find review thread for this comment${NC}"
        fi
    else
        echo -e "    ${RED}❌ Failed to fetch review threads${NC}"
    fi
    
    echo -e "  ${BLUE}Completed processing comment ${comment_id}${NC}"
    
    # Rate limiting delay
    sleep 2
done

echo
echo -e "${GREEN}🎉 Processing complete!${NC}"
echo -e "${YELLOW}Summary:${NC}"
echo "  - Comments processed: ${comment_count}"
echo "  - Search term: '${SEARCH_TEXT}'"
echo "  - Reply message: '${REPLY_MESSAGE}'"
echo
echo -e "${BLUE}Check the PR in GitHub's web interface to verify all changes.${NC}"