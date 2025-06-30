#!/bin/bash
#
# Bulk Add Issues to Project - Example Script
# 
# This script demonstrates how to add all issues from gwwtests/testxxxyyzzzzz 
# to gwwtests/projects/1 using the dotfile authentication pattern.
#
# Requirements:
# - GitHub CLI with proper project permissions
# - CLASSIC Personal access token with 'project' and 'read:project' scopes
# - Token stored in ${GITHUB_TOKEN_DOTFILE} as GITHUB_PERSONAL_ACCESS_TOKEN
# - ⚠️ Fine-grained tokens (new tokens) do NOT work with Projects v2 API
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Repository and project details
REPO_OWNER="gwwtests"
REPO_NAME="testxxxyyzzzzz"
PROJECT_OWNER="gwwtests"
PROJECT_NUMBER="1"

echo -e "${BLUE}=== Bulk Add Issues to Project ===${NC}"
echo "Repository: ${REPO_OWNER}/${REPO_NAME}"
echo "Target Project: ${PROJECT_OWNER}/projects/${PROJECT_NUMBER}"
echo

# Function to run commands with dotfile authentication
run_with_auth() {
    local token_file="${GITHUB_TOKEN_DOTFILE}"
    ( source "$token_file" ; export GH_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN" ; "$@" )
}

# Step 1: Test Authentication
echo -e "${BLUE}Step 1: Testing Authentication${NC}"
if run_with_auth gh auth status; then
    echo -e "${GREEN}✓ Authentication successful${NC}"
else
    echo -e "${RED}✗ Authentication failed${NC}"
    exit 1
fi
echo

# Step 2: Check API Rate Limits
echo -e "${BLUE}Step 2: Checking API Rate Limits${NC}"
RATE_LIMIT=$(run_with_auth gh api rate_limit | jq -r '.rate.remaining')
echo "Remaining API calls: $RATE_LIMIT"
if [ "$RATE_LIMIT" -lt 100 ]; then
    echo -e "${YELLOW}⚠ Low API rate limit remaining${NC}"
fi
echo

# Step 3: Get Project Information
echo -e "${BLUE}Step 3: Getting Project Information${NC}"
PROJECT_ID=$(run_with_auth gh api graphql -f query='
query {
  organization(login: "'$PROJECT_OWNER'") {
    projectV2(number: '$PROJECT_NUMBER') {
      id
      title
      url
    }
  }
}' | jq -r '.data.organization.projectV2.id')

if [ "$PROJECT_ID" = "null" ] || [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}✗ Could not find project ${PROJECT_NUMBER} for ${PROJECT_OWNER}${NC}"
    echo -e "${YELLOW}Possible issues:${NC}"
    echo "  - Using fine-grained token instead of classic token (most common)"
    echo "  - Project doesn't exist"
    echo "  - No permission to access the project"
    echo "  - Token missing 'project' or 'read:project' scopes"
    echo
    echo -e "${BLUE}Available troubleshooting steps:${NC}"
    echo "1. ⚠️ CRITICAL: Use classic token instead of fine-grained token"
    echo "2. Check your token file (${GITHUB_TOKEN_DOTFILE}) has the correct token"
    echo "3. Create project manually: https://github.com/orgs/$PROJECT_OWNER/projects/new"
    echo "4. Update token permissions: https://github.com/settings/tokens (use 'Tokens (classic)')"
    echo "5. Use a different project that you have access to"
    exit 1
else
    echo -e "${GREEN}✓ Found project: $PROJECT_ID${NC}"
fi
echo

# Step 4: Get Issues from Repository
echo -e "${BLUE}Step 4: Getting Issues from Repository${NC}"
ISSUES_JSON=$(run_with_auth gh issue list --repo "${REPO_OWNER}/${REPO_NAME}" --json number,title,url,state)
ISSUE_COUNT=$(echo "$ISSUES_JSON" | jq length)
echo "Found $ISSUE_COUNT issues"

if [ "$ISSUE_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}No issues found in repository${NC}"
    exit 0
fi

# Display issues
echo -e "${BLUE}Issues to be added:${NC}"
echo "$ISSUES_JSON" | jq -r '.[] | "  #\(.number): \(.title) (\(.state))"'
echo

# Step 5: Add Issues to Project
echo -e "${BLUE}Step 5: Adding Issues to Project${NC}"
ADDED=0
FAILED=0
SKIPPED=0

echo "$ISSUES_JSON" | jq -r '.[].url' | while read -r ISSUE_URL; do
    echo "Processing: $ISSUE_URL"
    
    # Extract issue information for content ID
    if [[ "$ISSUE_URL" =~ github\.com/([^/]+)/([^/]+)/issues/([0-9]+) ]]; then
        OWNER="${BASH_REMATCH[1]}"
        REPO="${BASH_REMATCH[2]}"
        NUMBER="${BASH_REMATCH[3]}"
        
        # Get content ID
        CONTENT_ID=$(run_with_auth gh api graphql -f query='
        query {
          repository(owner: "'$OWNER'", name: "'$REPO'") {
            issue(number: '$NUMBER') {
              id
            }
          }
        }' | jq -r '.data.repository.issue.id')
        
        if [ "$CONTENT_ID" = "null" ] || [ -z "$CONTENT_ID" ]; then
            echo -e "  ${RED}✗ Could not get content ID${NC}"
            FAILED=$((FAILED + 1))
            continue
        fi
        
        # Add to project
        RESULT=$(run_with_auth gh api graphql -f query='
        mutation {
          addProjectV2ItemById(input: {
            projectId: "'$PROJECT_ID'"
            contentId: "'$CONTENT_ID'"
          }) {
            item {
              id
              content {
                ... on Issue {
                  title
                  number
                }
              }
            }
          }
        }' 2>/dev/null || echo '{"errors":[{"message":"Failed"}]}')
        
        ITEM_ID=$(echo "$RESULT" | jq -r '.data.addProjectV2ItemById.item.id // empty')
        ERROR_MSG=$(echo "$RESULT" | jq -r '.errors[]?.message // empty')
        
        if [ -n "$ITEM_ID" ] && [ "$ITEM_ID" != "null" ]; then
            echo -e "  ${GREEN}✓ Added successfully${NC}"
            ADDED=$((ADDED + 1))
        elif echo "$ERROR_MSG" | grep -qi "already exists\|duplicate"; then
            echo -e "  ${YELLOW}⚠ Already exists${NC}"
            SKIPPED=$((SKIPPED + 1))
        else
            echo -e "  ${RED}✗ Failed: $ERROR_MSG${NC}"
            FAILED=$((FAILED + 1))
        fi
        
        # Rate limiting
        sleep 0.5
    else
        echo -e "  ${RED}✗ Invalid URL format${NC}"
        FAILED=$((FAILED + 1))
    fi
done

echo
echo -e "${BLUE}=== Summary ===${NC}"
echo "Total issues processed: $ISSUE_COUNT"
echo -e "${GREEN}Successfully added: $ADDED${NC}"
echo -e "${YELLOW}Already existed: $SKIPPED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"

if [ "$FAILED" -gt 0 ]; then
    echo
    echo -e "${YELLOW}If you encountered permission errors:${NC}"
    echo "1. Ensure you're using a CLASSIC personal access token (not fine-grained)"
    echo "2. Ensure your token has 'project' and 'read:project' scopes"
    echo "3. Visit: https://github.com/settings/tokens (use 'Tokens (classic)')"
    echo "4. Generate new CLASSIC token with proper scopes"
    echo "5. Update ${GITHUB_TOKEN_DOTFILE} with new token"
    echo "6. ⚠️ Fine-grained tokens cause empty/null API responses"
fi

echo
echo -e "${BLUE}Verify results at:${NC}"
echo "https://github.com/orgs/$PROJECT_OWNER/projects/$PROJECT_NUMBER"