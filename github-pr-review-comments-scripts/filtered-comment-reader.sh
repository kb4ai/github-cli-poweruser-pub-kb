#!/bin/bash

# Filtered GitHub PR Review Comments Reader
# Usage: ./filtered-comment-reader.sh OWNER REPO PR_NUMBER [OPTIONS]

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
FILTER_USER=""
FILTER_FILE=""
FILTER_TEXT=""
FILTER_DAYS=""
SHOW_REPLIES_ONLY=false
OUTPUT_FORMAT="human"

# Function to display usage
usage() {
    cat << EOF
Usage: $0 OWNER REPO PR_NUMBER [OPTIONS]

Options:
  -u, --user USER         Filter comments by specific user
  -f, --file PATH         Filter comments by file path
  -t, --text TEXT         Filter comments containing specific text
  -d, --days DAYS         Filter comments from last N days
  -r, --replies-only      Show only reply comments
  -o, --output FORMAT     Output format (human|json|csv) [default: human]
  -h, --help              Show this help message

Examples:
  $0 octocat Hello-World 37 --user johndoe
  $0 octocat Hello-World 37 --file "src/main.js" --days 7
  $0 octocat Hello-World 37 --text "LGTM" --output json
  $0 octocat Hello-World 37 --replies-only --output csv

EOF
    exit 1
}

# Parse command line arguments
OWNER="$1"
REPO="$2"
PR_NUMBER="$3"
shift 3

while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--user)
            FILTER_USER="$2"
            shift 2
            ;;
        -f|--file)
            FILTER_FILE="$2"
            shift 2
            ;;
        -t|--text)
            FILTER_TEXT="$2"
            shift 2
            ;;
        -d|--days)
            FILTER_DAYS="$2"
            shift 2
            ;;
        -r|--replies-only)
            SHOW_REPLIES_ONLY=true
            shift
            ;;
        -o|--output)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# Validate required parameters
if [ -z "$OWNER" ] || [ -z "$REPO" ] || [ -z "$PR_NUMBER" ]; then
    echo -e "${RED}Error: Missing required parameters${NC}"
    usage
fi

# Validate PR number is numeric
if ! [[ "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Error: PR_NUMBER must be a number${NC}"
    exit 1
fi

# Validate output format
if [[ ! "$OUTPUT_FORMAT" =~ ^(human|json|csv)$ ]]; then
    echo -e "${RED}Error: Output format must be human, json, or csv${NC}"
    exit 1
fi

# Validate days is numeric if provided
if [ -n "$FILTER_DAYS" ] && ! [[ "$FILTER_DAYS" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Error: Days must be a number${NC}"
    exit 1
fi

echo -e "${BLUE}Fetching filtered review comments for PR #${PR_NUMBER} in ${OWNER}/${REPO}...${NC}"

# Check authentication
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
review_comments=$(gh api --paginate repos/"$OWNER"/"$REPO"/pulls/"$PR_NUMBER"/comments 2>/dev/null)

if [ "$review_comments" = "[]" ] || [ -z "$review_comments" ]; then
    echo -e "${YELLOW}No review comments found for this PR.${NC}"
    exit 0
fi

# Build jq filter based on options
jq_filter="."

# Filter by user
if [ -n "$FILTER_USER" ]; then
    jq_filter="$jq_filter | map(select(.user.login == \"$FILTER_USER\"))"
    echo -e "${CYAN}Filtering by user: $FILTER_USER${NC}"
fi

# Filter by file
if [ -n "$FILTER_FILE" ]; then
    jq_filter="$jq_filter | map(select(.path == \"$FILTER_FILE\"))"
    echo -e "${CYAN}Filtering by file: $FILTER_FILE${NC}"
fi

# Filter by text content
if [ -n "$FILTER_TEXT" ]; then
    jq_filter="$jq_filter | map(select(.body | test(\"$FILTER_TEXT\"; \"i\")))"
    echo -e "${CYAN}Filtering by text: $FILTER_TEXT${NC}"
fi

# Filter by date
if [ -n "$FILTER_DAYS" ]; then
    cutoff_date=$(date -d "$FILTER_DAYS days ago" -Iseconds)
    jq_filter="$jq_filter | map(select(.created_at > \"$cutoff_date\"))"
    echo -e "${CYAN}Filtering by last $FILTER_DAYS days${NC}"
fi

# Filter replies only
if [ "$SHOW_REPLIES_ONLY" = true ]; then
    jq_filter="$jq_filter | map(select(.in_reply_to_id != null))"
    echo -e "${CYAN}Showing only reply comments${NC}"
fi

# Apply filters
filtered_comments=$(echo "$review_comments" | jq "$jq_filter")

# Check if any comments remain after filtering
if [ "$filtered_comments" = "[]" ] || [ -z "$filtered_comments" ]; then
    echo -e "${YELLOW}No comments match the specified filters.${NC}"
    exit 0
fi

# Count filtered comments
comment_count=$(echo "$filtered_comments" | jq '. | length')
echo -e "${GREEN}Found ${comment_count} comment(s) matching filters:${NC}"
echo

# Output in requested format
case $OUTPUT_FORMAT in
    "json")
        echo "$filtered_comments"
        ;;
    "csv")
        echo "user,file,line,body,created_at,html_url,reply_to_id"
        echo "$filtered_comments" | jq -r '
            .[] | 
            [
                .user.login,
                .path // "",
                .line // "",
                (.body | gsub("\n"; " ") | gsub("\""; "\"\"" )),
                .created_at,
                .html_url,
                .in_reply_to_id // ""
            ] | @csv
        '
        ;;
    "human"|*)
        echo "$filtered_comments" | jq -r '
            .[] | 
            "📍 File: \(.path // "N/A"):\(.line // "general")
            👤 User: \(.user.login) (\(.author_association))
            💬 Comment: \(.body)
            📅 Created: \(.created_at)
            🔗 URL: \(.html_url)" +
            (if .in_reply_to_id then "\n↪️  Reply to: \(.in_reply_to_id)" else "" end) +
            "\n" + ("─" * 80) + "\n"
        '
        ;;
esac

# Summary
echo
echo -e "${BLUE}Filter Summary:${NC}"
[ -n "$FILTER_USER" ] && echo -e "  User: $FILTER_USER"
[ -n "$FILTER_FILE" ] && echo -e "  File: $FILTER_FILE"
[ -n "$FILTER_TEXT" ] && echo -e "  Text: $FILTER_TEXT"
[ -n "$FILTER_DAYS" ] && echo -e "  Days: $FILTER_DAYS"
[ "$SHOW_REPLIES_ONLY" = true ] && echo -e "  Replies only: Yes"
echo -e "  Total matches: $comment_count"