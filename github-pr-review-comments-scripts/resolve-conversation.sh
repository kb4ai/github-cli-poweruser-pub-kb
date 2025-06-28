#!/bin/bash

# Resolve or Unresolve GitHub PR Review Comment Conversation Thread
# Usage: ./resolve-conversation.sh OWNER REPO PR_NUMBER COMMENT_ID [--unresolve]

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo "Usage: $0 OWNER REPO PR_NUMBER COMMENT_ID [--unresolve]"
    echo "Example: $0 FlowCortex flowcortex 107 2172519617"
    echo "Example: $0 FlowCortex flowcortex 107 2172519617 --unresolve"
    echo ""
    echo "This script resolves or unresolves a PR review comment conversation thread using GitHub's GraphQL API."
    echo "By default, it resolves the thread. Use --unresolve flag to unresolve instead."
    echo "Note: Requires write permissions to the repository."
    exit 1
}

# Validate input parameters
if [ $# -lt 4 ] || [ $# -gt 5 ]; then
    echo -e "${RED}Error: Invalid number of arguments${NC}"
    usage
fi

OWNER="$1"
REPO="$2"
PR_NUMBER="$3"
COMMENT_ID="$4"
UNRESOLVE_FLAG="$5"

# Check if unresolve flag is provided
if [ "$UNRESOLVE_FLAG" = "--unresolve" ]; then
    ACTION="unresolve"
    ACTION_VERB="Unresolving"
    ACTION_PAST="unresolved"
elif [ -n "$UNRESOLVE_FLAG" ]; then
    echo -e "${RED}Error: Invalid flag '$UNRESOLVE_FLAG'. Only '--unresolve' is supported.${NC}"
    usage
else
    ACTION="resolve"
    ACTION_VERB="Resolving"
    ACTION_PAST="resolved"
fi

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

echo -e "${BLUE}${ACTION_VERB} conversation for comment ID ${COMMENT_ID} on PR #${PR_NUMBER} in ${OWNER}/${REPO}...${NC}"

# Check if GitHub CLI is authenticated
if ! gh auth status >/dev/null 2>&1; then
    echo -e "${RED}Error: GitHub CLI not authenticated. Run 'gh auth login' first.${NC}"
    exit 1
fi

# CRITICAL SAFETY CHECK: Verify comment exists before attempting resolution
echo -e "${YELLOW}SAFETY CHECK: Validating comment ${COMMENT_ID} exists...${NC}"
if ! comment_validation=$(gh api repos/"$OWNER"/"$REPO"/pulls/comments/"$COMMENT_ID" 2>/dev/null); then
    echo -e "${RED}CRITICAL ERROR: Comment ID ${COMMENT_ID} does not exist${NC}"
    echo -e "${RED}SAFETY EXIT: Cannot resolve non-existent comment${NC}"
    exit 1
fi

echo -e "${GREEN}Comment validation passed - comment exists${NC}"

# Step 1: Get the PR's review threads using GraphQL to find the thread ID
echo -e "${YELLOW}Step 1: Finding review thread ID for comment ${COMMENT_ID}...${NC}"

# GraphQL query to get review threads and their comments
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
              id
              databaseId
              body
              author {
                login
              }
              createdAt
            }
          }
        }
      }
    }
  }
}'

# Execute GraphQL query
if ! review_threads=$(gh api graphql \
  -f query="$graphql_query" \
  -F owner="$OWNER" \
  -F name="$REPO" \
  -F number="$PR_NUMBER" 2>/dev/null); then
    echo -e "${RED}Error: Failed to fetch review threads via GraphQL${NC}"
    exit 1
fi

# Find the thread ID that contains our comment
thread_id=$(echo "$review_threads" | jq -r --arg comment_id "$COMMENT_ID" '
  .data.repository.pullRequest.reviewThreads.nodes[] | 
  select(.comments.nodes[] | .databaseId == ($comment_id | tonumber)) | 
  .id
')

if [ -z "$thread_id" ] || [ "$thread_id" = "null" ]; then
    echo -e "${RED}Error: Could not find review thread for comment ID ${COMMENT_ID}${NC}"
    echo -e "${YELLOW}This might mean:${NC}"
    echo "  - The comment ID is incorrect"
    echo "  - The comment is not part of a review thread"
    echo "  - The comment is a general PR comment (not a review comment)"
    exit 1
fi

# Check if thread is already resolved
thread_status=$(echo "$review_threads" | jq -r --arg comment_id "$COMMENT_ID" '
  .data.repository.pullRequest.reviewThreads.nodes[] | 
  select(.comments.nodes[] | .databaseId == ($comment_id | tonumber)) | 
  .isResolved
')

echo -e "${GREEN}Found review thread: ${thread_id}${NC}"
echo -e "${BLUE}Current status: $([ "$thread_status" = "true" ] && echo "Resolved" || echo "Unresolved")${NC}"

# Check for conflicting states
if [ "$ACTION" = "resolve" ] && [ "$thread_status" = "true" ]; then
    echo -e "${YELLOW}Warning: Thread is already resolved.${NC}"
    echo -e "${RED}SAFETY PROMPT: This comment thread is already resolved.${NC}"
    echo "Do you want to continue anyway? This action cannot be undone. (y/N)"
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Operation cancelled for safety.${NC}"
        exit 0
    fi
    echo -e "${YELLOW}User confirmed - proceeding with already-resolved thread${NC}"
elif [ "$ACTION" = "unresolve" ] && [ "$thread_status" = "false" ]; then
    echo -e "${YELLOW}Warning: Thread is already unresolved.${NC}"
    echo -e "${RED}SAFETY PROMPT: This comment thread is already unresolved.${NC}"
    echo "Do you want to continue anyway? (y/N)"
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Operation cancelled for safety.${NC}"
        exit 0
    fi
    echo -e "${YELLOW}User confirmed - proceeding with already-unresolved thread${NC}"
fi

# Step 2: Resolve or unresolve the thread using GraphQL mutation
echo -e "${YELLOW}Step 2: ${ACTION_VERB} the conversation thread...${NC}"

# Choose the appropriate GraphQL mutation based on action
if [ "$ACTION" = "resolve" ]; then
    mutation='
    mutation($threadId: ID!) {
      resolveReviewThread(input: {threadId: $threadId}) {
        thread {
          id
          isResolved
        }
      }
    }'
    result_path='.data.resolveReviewThread.thread.isResolved'
    expected_status="true"
else
    mutation='
    mutation($threadId: ID!) {
      unresolveReviewThread(input: {threadId: $threadId}) {
        thread {
          id
          isResolved
        }
      }
    }'
    result_path='.data.unresolveReviewThread.thread.isResolved'
    expected_status="false"
fi

# Execute the mutation
if mutation_result=$(gh api graphql \
  -f query="$mutation" \
  -f threadId="$thread_id" 2>/dev/null); then
    
    # Check if the mutation was successful
    final_status=$(echo "$mutation_result" | jq -r "$result_path")
    
    if [ "$final_status" = "$expected_status" ]; then
        echo -e "${GREEN}✅ Conversation ${ACTION_PAST} successfully!${NC}"
        echo "Thread ID: $thread_id"
        echo "Status: $([ "$final_status" = "true" ] && echo "Resolved" || echo "Unresolved")"
    else
        echo -e "${RED}❌ Failed to ${ACTION} conversation${NC}"
        echo "Response: $mutation_result"
        exit 1
    fi
else
    echo -e "${RED}Error: Failed to ${ACTION} conversation. This might be due to:${NC}"
    echo "  - Insufficient permissions (need write access to repository)"
    echo "  - Thread is already ${ACTION_PAST}"
    echo "  - GraphQL API limitations"
    echo "  - Invalid thread ID"
    exit 1
fi

echo
echo -e "${BLUE}Conversation ${ACTION} completed successfully.${NC}"
echo -e "${YELLOW}Note: You can verify the ${ACTION} by checking the PR in GitHub's web interface.${NC}"