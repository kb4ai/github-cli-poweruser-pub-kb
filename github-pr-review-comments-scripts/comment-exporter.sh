#!/bin/bash

# GitHub PR Review Comments Exporter
# Usage: ./comment-exporter.sh OWNER REPO PR_NUMBER OUTPUT_FILE [FORMAT]

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
    cat << EOF
Usage: $0 OWNER REPO PR_NUMBER OUTPUT_FILE [FORMAT]

Formats:
  json      - Export as JSON (default)
  csv       - Export as CSV
  markdown  - Export as Markdown
  html      - Export as HTML
  text      - Export as plain text

Examples:
  $0 octocat Hello-World 37 comments.json
  $0 octocat Hello-World 37 comments.csv csv
  $0 octocat Hello-World 37 report.md markdown
  $0 octocat Hello-World 37 report.html html

EOF
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
OUTPUT_FILE="$4"
FORMAT="${5:-json}"

# Validate PR number is numeric
if ! [[ "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Error: PR_NUMBER must be a number${NC}"
    exit 1
fi

# Validate format
if [[ ! "$FORMAT" =~ ^(json|csv|markdown|html|text)$ ]]; then
    echo -e "${RED}Error: Format must be json, csv, markdown, html, or text${NC}"
    exit 1
fi

echo -e "${BLUE}Exporting review comments for PR #${PR_NUMBER} in ${OWNER}/${REPO}...${NC}"

# Check authentication
if ! gh auth status >/dev/null 2>&1; then
    echo -e "${RED}Error: GitHub CLI not authenticated. Run 'gh auth login' first.${NC}"
    exit 1
fi

# Check if PR exists and get PR info
echo -e "${CYAN}Fetching PR information...${NC}"
pr_info=$(gh api repos/"$OWNER"/"$REPO"/pulls/"$PR_NUMBER" 2>/dev/null)
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: PR #${PR_NUMBER} not found in ${OWNER}/${REPO}${NC}"
    exit 1
fi

pr_title=$(echo "$pr_info" | jq -r '.title')
pr_author=$(echo "$pr_info" | jq -r '.user.login')
pr_created=$(echo "$pr_info" | jq -r '.created_at')
pr_url=$(echo "$pr_info" | jq -r '.html_url')

# Fetch review comments
echo -e "${CYAN}Fetching review comments...${NC}"
review_comments=$(gh api --paginate repos/"$OWNER"/"$REPO"/pulls/"$PR_NUMBER"/comments 2>/dev/null)

# Fetch issue comments
echo -e "${CYAN}Fetching general PR comments...${NC}"
issue_comments=$(gh api --paginate repos/"$OWNER"/"$REPO"/issues/"$PR_NUMBER"/comments 2>/dev/null)

# Count comments
review_count=$(echo "$review_comments" | jq '. | length' 2>/dev/null || echo "0")
issue_count=$(echo "$issue_comments" | jq '. | length' 2>/dev/null || echo "0")
total_count=$((review_count + issue_count))

echo -e "${GREEN}Found ${review_count} review comments and ${issue_count} general comments${NC}"

# Create output directory if it doesn't exist
output_dir=$(dirname "$OUTPUT_FILE")
mkdir -p "$output_dir"

# Export based on format
case $FORMAT in
    "json")
        echo -e "${CYAN}Exporting to JSON format...${NC}"
        jq -n \
            --argjson pr_info "$pr_info" \
            --argjson review_comments "$review_comments" \
            --argjson issue_comments "$issue_comments" \
            '{
                metadata: {
                    exported_at: now | strftime("%Y-%m-%dT%H:%M:%SZ"),
                    repository: "\($pr_info.base.repo.full_name)",
                    pr_number: $pr_info.number,
                    pr_title: $pr_info.title,
                    pr_author: $pr_info.user.login,
                    pr_created_at: $pr_info.created_at,
                    pr_url: $pr_info.html_url,
                    total_review_comments: ($review_comments | length),
                    total_issue_comments: ($issue_comments | length)
                },
                review_comments: $review_comments,
                issue_comments: $issue_comments
            }' > "$OUTPUT_FILE"
        ;;
    
    "csv")
        echo -e "${CYAN}Exporting to CSV format...${NC}"
        {
            echo "type,user,body,file,line,created_at,updated_at,html_url,reply_to_id"
            
            # Review comments
            echo "$review_comments" | jq -r '
                .[] | 
                [
                    "review",
                    .user.login,
                    (.body | gsub("\n"; " ") | gsub("\""; "\"\"" )),
                    (.path // ""),
                    (.line // ""),
                    .created_at,
                    .updated_at,
                    .html_url,
                    (.in_reply_to_id // "")
                ] | @csv
            '
            
            # Issue comments
            echo "$issue_comments" | jq -r '
                .[] | 
                [
                    "issue",
                    .user.login,
                    (.body | gsub("\n"; " ") | gsub("\""; "\"\"" )),
                    "",
                    "",
                    .created_at,
                    .updated_at,
                    .html_url,
                    ""
                ] | @csv
            '
        } > "$OUTPUT_FILE"
        ;;
    
    "markdown")
        echo -e "${CYAN}Exporting to Markdown format...${NC}"
        {
            echo "# PR Review Comments Export"
            echo ""
            echo "**Repository:** ${OWNER}/${REPO}  "
            echo "**PR #:** ${PR_NUMBER}  "
            echo "**Title:** ${pr_title}  "
            echo "**Author:** ${pr_author}  "
            echo "**Created:** ${pr_created}  "
            echo "**URL:** ${pr_url}  "
            echo "**Exported:** $(date -Iseconds)  "
            echo ""
            echo "## Summary"
            echo ""
            echo "- Review Comments (inline): ${review_count}"
            echo "- General Comments: ${issue_count}"
            echo "- Total Comments: ${total_count}"
            echo ""
            
            if [ "$review_count" -gt 0 ]; then
                echo "## Review Comments (Inline)"
                echo ""
                echo "$review_comments" | jq -r '
                    .[] | 
                    "### Comment by @\(.user.login)
                    
                    **File:** `\(.path // "N/A")`  
                    **Line:** \(.line // "N/A")  
                    **Created:** \(.created_at)  
                    **URL:** \(.html_url)  " +
                    (if .in_reply_to_id then "**Reply to:** \(.in_reply_to_id)  " else "" end) + "
                    
                    \(.body)
                    
                    ---
                    "
                '
            fi
            
            if [ "$issue_count" -gt 0 ]; then
                echo ""
                echo "## General Comments"
                echo ""
                echo "$issue_comments" | jq -r '
                    .[] | 
                    "### Comment by @\(.user.login)
                    
                    **Created:** \(.created_at)  
                    **URL:** \(.html_url)  
                    
                    \(.body)
                    
                    ---
                    "
                '
            fi
        } > "$OUTPUT_FILE"
        ;;
    
    "html")
        echo -e "${CYAN}Exporting to HTML format...${NC}"
        {
            cat << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PR #${PR_NUMBER} Review Comments - ${OWNER}/${REPO}</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif; line-height: 1.6; margin: 40px; }
        .header { border-bottom: 2px solid #e1e4e8; padding-bottom: 20px; margin-bottom: 30px; }
        .metadata { background: #f6f8fa; padding: 15px; border-radius: 6px; margin-bottom: 20px; }
        .comment { border: 1px solid #e1e4e8; border-radius: 6px; margin-bottom: 20px; padding: 15px; }
        .comment-header { background: #f6f8fa; margin: -15px -15px 15px -15px; padding: 10px 15px; border-bottom: 1px solid #e1e4e8; }
        .user { font-weight: bold; color: #0366d6; }
        .file-info { font-family: 'SFMono-Regular', Consolas, 'Liberation Mono', Menlo, monospace; font-size: 12px; color: #586069; }
        .comment-body { white-space: pre-wrap; }
        .review-comment { border-left: 4px solid #0366d6; }
        .issue-comment { border-left: 4px solid #28a745; }
        .reply { margin-left: 20px; border-left: 3px solid #f39c12; }
    </style>
</head>
<body>
    <div class="header">
        <h1>PR Review Comments Export</h1>
        <div class="metadata">
            <strong>Repository:</strong> ${OWNER}/${REPO}<br>
            <strong>PR #:</strong> ${PR_NUMBER}<br>
            <strong>Title:</strong> ${pr_title}<br>
            <strong>Author:</strong> ${pr_author}<br>
            <strong>Created:</strong> ${pr_created}<br>
            <strong>URL:</strong> <a href="${pr_url}">${pr_url}</a><br>
            <strong>Exported:</strong> $(date -Iseconds)
        </div>
        <div class="metadata">
            <strong>Summary:</strong> ${review_count} review comments, ${issue_count} general comments (${total_count} total)
        </div>
    </div>
EOF
            
            if [ "$review_count" -gt 0 ]; then
                echo "    <h2>Review Comments (Inline)</h2>"
                echo "$review_comments" | jq -r '
                    .[] | 
                    "    <div class=\"comment review-comment" + (if .in_reply_to_id then " reply" else "" end) + "\">
                        <div class=\"comment-header\">
                            <span class=\"user\">@\(.user.login)</span> • 
                            <span class=\"file-info\">\(.path // "N/A"):\(.line // "N/A")</span> • 
                            <span>\(.created_at)</span>" +
                            (if .in_reply_to_id then " • Reply to #\(.in_reply_to_id)" else "") + "
                            <div style=\"float: right;\"><a href=\"\(.html_url)\">View on GitHub</a></div>
                        </div>
                        <div class=\"comment-body\">\(.body)</div>
                    </div>"
                '
            fi
            
            if [ "$issue_count" -gt 0 ]; then
                echo "    <h2>General Comments</h2>"
                echo "$issue_comments" | jq -r '
                    .[] | 
                    "    <div class=\"comment issue-comment\">
                        <div class=\"comment-header\">
                            <span class=\"user\">@\(.user.login)</span> • 
                            <span>\(.created_at)</span>
                            <div style=\"float: right;\"><a href=\"\(.html_url)\">View on GitHub</a></div>
                        </div>
                        <div class=\"comment-body\">\(.body)</div>
                    </div>"
                '
            fi
            
            echo "</body>"
            echo "</html>"
        } > "$OUTPUT_FILE"
        ;;
    
    "text")
        echo -e "${CYAN}Exporting to plain text format...${NC}"
        {
            echo "PR REVIEW COMMENTS EXPORT"
            echo "========================="
            echo ""
            echo "Repository: ${OWNER}/${REPO}"
            echo "PR #: ${PR_NUMBER}"
            echo "Title: ${pr_title}"
            echo "Author: ${pr_author}"
            echo "Created: ${pr_created}"
            echo "URL: ${pr_url}"
            echo "Exported: $(date -Iseconds)"
            echo ""
            echo "SUMMARY"
            echo "-------"
            echo "Review Comments (inline): ${review_count}"
            echo "General Comments: ${issue_count}"
            echo "Total Comments: ${total_count}"
            echo ""
            
            if [ "$review_count" -gt 0 ]; then
                echo "REVIEW COMMENTS (INLINE)"
                echo "========================"
                echo ""
                echo "$review_comments" | jq -r '
                    .[] | 
                    "File: \(.path // "N/A"):\(.line // "N/A")
                    User: \(.user.login) (\(.author_association))
                    Created: \(.created_at)
                    URL: \(.html_url)" +
                    (if .in_reply_to_id then "\nReply to: \(.in_reply_to_id)" else "" end) + "
                    
                    \(.body)
                    
                    " + ("=" * 80) + "
                    "
                '
            fi
            
            if [ "$issue_count" -gt 0 ]; then
                echo ""
                echo "GENERAL COMMENTS"
                echo "================"
                echo ""
                echo "$issue_comments" | jq -r '
                    .[] | 
                    "User: \(.user.login) (\(.author_association))
                    Created: \(.created_at)
                    URL: \(.html_url)
                    
                    \(.body)
                    
                    " + ("=" * 80) + "
                    "
                '
            fi
        } > "$OUTPUT_FILE"
        ;;
esac

echo -e "${GREEN}Export completed successfully!${NC}"
echo -e "Output file: ${OUTPUT_FILE}"
echo -e "Format: ${FORMAT}"
echo -e "Total comments exported: ${total_count}"

# Show file size
if command -v du >/dev/null 2>&1; then
    file_size=$(du -h "$OUTPUT_FILE" | cut -f1)
    echo -e "File size: ${file_size}"
fi