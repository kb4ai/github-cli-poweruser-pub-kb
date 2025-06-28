#!/bin/bash

# Batch GitHub PR Review Comments Analyzer
# Usage: ./batch-pr-analyzer.sh OWNER REPO [OPTIONS]

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Default values
STATE="all"
DAYS=""
AUTHOR=""
OUTPUT_FILE=""
MAX_PRS=10
DETAILED=false

# Function to display usage
usage() {
    cat << EOF
Usage: $0 OWNER REPO [OPTIONS]

Options:
  -s, --state STATE       PR state (open|closed|all) [default: all]
  -d, --days DAYS         Analyze PRs from last N days
  -a, --author AUTHOR     Filter PRs by author
  -o, --output FILE       Save analysis to file
  -n, --max-prs N         Maximum number of PRs to analyze [default: 10]
  -v, --detailed          Include detailed comment analysis
  -h, --help              Show this help message

Examples:
  $0 octocat Hello-World --state open --days 30
  $0 octocat Hello-World --author johndoe --detailed
  $0 octocat Hello-World --max-prs 20 --output analysis.json

EOF
    exit 1
}

# Parse command line arguments
if [ $# -lt 2 ]; then
    echo -e "${RED}Error: Missing required parameters${NC}"
    usage
fi

OWNER="$1"
REPO="$2"
shift 2

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--state)
            STATE="$2"
            shift 2
            ;;
        -d|--days)
            DAYS="$2"
            shift 2
            ;;
        -a|--author)
            AUTHOR="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -n|--max-prs)
            MAX_PRS="$2"
            shift 2
            ;;
        -v|--detailed)
            DETAILED=true
            shift
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

# Validate parameters
if [[ ! "$STATE" =~ ^(open|closed|all)$ ]]; then
    echo -e "${RED}Error: State must be open, closed, or all${NC}"
    exit 1
fi

if [ -n "$DAYS" ] && ! [[ "$DAYS" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Error: Days must be a number${NC}"
    exit 1
fi

if ! [[ "$MAX_PRS" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Error: Max PRs must be a number${NC}"
    exit 1
fi

echo -e "${BLUE}Analyzing PR review comments for ${OWNER}/${REPO}...${NC}"

# Check authentication
if ! gh auth status >/dev/null 2>&1; then
    echo -e "${RED}Error: GitHub CLI not authenticated. Run 'gh auth login' first.${NC}"
    exit 1
fi

# Build PR query parameters
pr_params="state=$STATE&per_page=$MAX_PRS"

if [ -n "$AUTHOR" ]; then
    pr_params="$pr_params&head=$AUTHOR:"
    echo -e "${CYAN}Filtering by author: $AUTHOR${NC}"
fi

# Fetch PRs
echo -e "${CYAN}Fetching PRs (max: $MAX_PRS, state: $STATE)...${NC}"
prs=$(gh api "repos/$OWNER/$REPO/pulls?$pr_params" 2>/dev/null)

if [ "$prs" = "[]" ] || [ -z "$prs" ]; then
    echo -e "${YELLOW}No PRs found matching criteria.${NC}"
    exit 0
fi

# Filter by date if specified
if [ -n "$DAYS" ]; then
    cutoff_date=$(date -d "$DAYS days ago" -Iseconds)
    prs=$(echo "$prs" | jq --arg date "$cutoff_date" 'map(select(.created_at > $date))')
    echo -e "${CYAN}Filtering by last $DAYS days${NC}"
fi

pr_count=$(echo "$prs" | jq '. | length')
echo -e "${GREEN}Found ${pr_count} PR(s) to analyze${NC}"
echo

# Initialize analysis data
declare -A user_stats
declare -A file_stats
total_review_comments=0
total_issue_comments=0
total_prs=0

# Start analysis output
analysis_start_time=$(date -Iseconds)
if [ -n "$OUTPUT_FILE" ]; then
    echo -e "${CYAN}Analysis will be saved to: $OUTPUT_FILE${NC}"
    exec 3>"$OUTPUT_FILE"
    echo '{"metadata":{"analysis_start":"'$analysis_start_time'","repository":"'$OWNER/$REPO'","filters":{"state":"'$STATE'"' >> "$OUTPUT_FILE"
    [ -n "$DAYS" ] && echo ',"days":'$DAYS >> "$OUTPUT_FILE"
    [ -n "$AUTHOR" ] && echo ',"author":"'$AUTHOR'"' >> "$OUTPUT_FILE"
    echo '},"pr_count":'$pr_count',"detailed":'$DETAILED'},"analysis":{"prs":[' >> "$OUTPUT_FILE"
    first_pr=true
fi

# Analyze each PR
echo "$prs" | jq -c '.[]' | while IFS= read -r pr; do
    pr_number=$(echo "$pr" | jq -r '.number')
    pr_title=$(echo "$pr" | jq -r '.title')
    pr_author=$(echo "$pr" | jq -r '.user.login')
    pr_created=$(echo "$pr" | jq -r '.created_at')
    pr_url=$(echo "$pr" | jq -r '.html_url')
    
    echo -e "${MAGENTA}Analyzing PR #${pr_number}: ${pr_title}${NC}"
    echo -e "  Author: ${pr_author}, Created: ${pr_created}"
    
    # Fetch review comments
    review_comments=$(gh api --paginate "repos/$OWNER/$REPO/pulls/$pr_number/comments" 2>/dev/null || echo "[]")
    review_count=$(echo "$review_comments" | jq '. | length')
    
    # Fetch issue comments
    issue_comments=$(gh api --paginate "repos/$OWNER/$REPO/issues/$pr_number/comments" 2>/dev/null || echo "[]")
    issue_count=$(echo "$issue_comments" | jq '. | length')
    
    total_comments=$((review_count + issue_count))
    
    echo -e "  Review comments: ${review_count}, General comments: ${issue_count}, Total: ${total_comments}"
    
    # Update totals
    total_review_comments=$((total_review_comments + review_count))
    total_issue_comments=$((total_issue_comments + issue_count))
    total_prs=$((total_prs + 1))
    
    # Detailed analysis
    if [ "$DETAILED" = true ] && [ "$review_count" -gt 0 ]; then
        echo -e "  ${CYAN}Detailed comment analysis:${NC}"
        
        # Top commenters for this PR
        top_commenters=$(echo "$review_comments" | jq -r 'group_by(.user.login) | map({user: .[0].user.login, count: length}) | sort_by(.count) | reverse | .[0:3] | .[] | "    \(.user): \(.count) comments"')
        if [ -n "$top_commenters" ]; then
            echo -e "  Top commenters:"
            echo "$top_commenters"
        fi
        
        # Most commented files
        top_files=$(echo "$review_comments" | jq -r 'group_by(.path) | map({file: .[0].path, count: length}) | sort_by(.count) | reverse | .[0:3] | .[] | "    \(.file): \(.count) comments"')
        if [ -n "$top_files" ]; then
            echo -e "  Most commented files:"
            echo "$top_files"
        fi
    fi
    
    # Save to output file if specified
    if [ -n "$OUTPUT_FILE" ]; then
        if [ "$first_pr" = false ]; then
            echo ',' >> "$OUTPUT_FILE"
        fi
        
        pr_analysis=$(jq -n \
            --argjson pr "$pr" \
            --argjson review_comments "$review_comments" \
            --argjson issue_comments "$issue_comments" \
            --arg review_count "$review_count" \
            --arg issue_count "$issue_count" \
            '{
                pr_info: {
                    number: $pr.number,
                    title: $pr.title,
                    author: $pr.user.login,
                    created_at: $pr.created_at,
                    html_url: $pr.html_url
                },
                comment_stats: {
                    review_comments: ($review_count | tonumber),
                    issue_comments: ($issue_count | tonumber),
                    total_comments: (($review_count | tonumber) + ($issue_count | tonumber))
                }
            }' + \
            if [ "$DETAILED" = true ]; then \
                echo ' + {detailed_analysis: {review_comments: $review_comments, issue_comments: $issue_comments}}'; \
            else \
                echo ''; \
            fi)
        
        echo "$pr_analysis" >> "$OUTPUT_FILE"
        first_pr=false
    fi
    
    echo
done

# Calculate and display summary
echo -e "${BLUE}Analysis Summary:${NC}"
echo -e "  Repository: ${OWNER}/${REPO}"
echo -e "  PRs analyzed: ${total_prs}"
echo -e "  Total review comments: ${total_review_comments}"
echo -e "  Total general comments: ${total_issue_comments}"
echo -e "  Total comments: $((total_review_comments + total_issue_comments))"

if [ "$total_prs" -gt 0 ]; then
    avg_review=$((total_review_comments / total_prs))
    avg_issue=$((total_issue_comments / total_prs))
    avg_total=$(((total_review_comments + total_issue_comments) / total_prs))
    
    echo -e "  Average review comments per PR: ${avg_review}"
    echo -e "  Average general comments per PR: ${avg_issue}"
    echo -e "  Average total comments per PR: ${avg_total}"
fi

# Finalize output file
if [ -n "$OUTPUT_FILE" ]; then
    analysis_end_time=$(date -Iseconds)
    echo '],"summary":{"total_prs":'$total_prs',"total_review_comments":'$total_review_comments',"total_issue_comments":'$total_issue_comments',"analysis_end":"'$analysis_end_time'"}}' >> "$OUTPUT_FILE"
    echo -e "${GREEN}Analysis saved to: $OUTPUT_FILE${NC}"
fi

echo -e "${GREEN}Batch analysis completed!${NC}"