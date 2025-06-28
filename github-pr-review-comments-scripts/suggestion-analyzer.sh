#!/bin/bash

# suggestion-analyzer.sh - Advanced analysis and reporting for GitHub PR suggestions
# 
# This script provides comprehensive analysis capabilities for GitHub Pull Request
# suggested changes, including cross-PR analysis, team metrics, acceptance tracking,
# and advanced reporting features.
#
# Usage: ./suggestion-analyzer.sh COMMAND OWNER REPO [OPTIONS]
#
# Commands:
#   pr-analysis      - Analyze suggestions in a specific PR
#   repo-analysis    - Analyze suggestions across multiple PRs in repository
#   user-analysis    - Analyze suggestion patterns for specific users
#   file-analysis    - Analyze suggestions by file patterns
#   trend-analysis   - Analyze suggestion trends over time
#   acceptance-rate  - Calculate suggestion acceptance rates (requires manual tracking)
#   team-metrics     - Generate team suggestion metrics
#   export-report    - Generate comprehensive reports
#
# Examples:
#   # Analyze specific PR
#   ./suggestion-analyzer.sh pr-analysis octocat Hello-World --pr 123
#
#   # Repository-wide analysis
#   ./suggestion-analyzer.sh repo-analysis octocat Hello-World --days 30 --limit 50
#
#   # User pattern analysis
#   ./suggestion-analyzer.sh user-analysis octocat Hello-World --user johndoe --days 90
#
#   # File pattern analysis
#   ./suggestion-analyzer.sh file-analysis octocat Hello-World --pattern "*.js" --days 30
#
#   # Trend analysis
#   ./suggestion-analyzer.sh trend-analysis octocat Hello-World --days 180
#
#   # Generate comprehensive report
#   ./suggestion-analyzer.sh export-report octocat Hello-World --format html --output report.html
#
# Requirements:
#   - GitHub CLI (gh) installed and authenticated
#   - jq for JSON processing
#   - date command for date calculations
#   - Read permissions to the repository

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variables
COMMAND=""
OWNER=""
REPO=""
PR_NUMBER=""
USER_FILTER=""
FILE_PATTERN=""
DAYS_LIMIT="30"
PR_LIMIT="50"
OUTPUT_FORMAT="human"
OUTPUT_FILE=""
VERBOSE=false
INCLUDE_CLOSED=true

# Function to display usage
usage() {
    echo "Usage: $0 COMMAND OWNER REPO [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  pr-analysis      Analyze suggestions in a specific PR"
    echo "  repo-analysis    Analyze suggestions across multiple PRs in repository"
    echo "  user-analysis    Analyze suggestion patterns for specific users"
    echo "  file-analysis    Analyze suggestions by file patterns"
    echo "  trend-analysis   Analyze suggestion trends over time"
    echo "  team-metrics     Generate team suggestion metrics"
    echo "  export-report    Generate comprehensive reports"
    echo ""
    echo "Options:"
    echo "  --pr NUMBER         Specific PR number (for pr-analysis)"
    echo "  --user USERNAME     Filter by specific user"
    echo "  --pattern PATTERN   File pattern to analyze (e.g., '*.js', 'src/**')"
    echo "  --days DAYS         Number of days to look back (default: 30)"
    echo "  --limit NUMBER      Maximum number of PRs to analyze (default: 50)"
    echo "  --format FORMAT     Output format: human|json|csv|markdown|html"
    echo "  --output FILE       Output file (default: stdout)"
    echo "  --open-only        Only analyze open PRs"
    echo "  --verbose          Enable verbose output"
    echo ""
    echo "Examples:"
    echo "  # Analyze specific PR"
    echo "  $0 pr-analysis octocat Hello-World --pr 123"
    echo ""
    echo "  # Repository-wide analysis"
    echo "  $0 repo-analysis octocat Hello-World --days 30 --limit 50"
    echo ""
    echo "  # User pattern analysis"
    echo "  $0 user-analysis octocat Hello-World --user johndoe --days 90"
    echo ""
    echo "  # Generate comprehensive report"
    echo "  $0 export-report octocat Hello-World --format html --output report.html"
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

log_debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${PURPLE}[DEBUG]${NC} $1"
    fi
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
    
    if ! command -v date &> /dev/null; then
        missing_tools+=("date")
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

# Function to get PRs within date range
get_prs_in_range() {
    local owner="$1"
    local repo="$2"
    local days="$3"
    local limit="$4"
    local include_closed="$5"
    
    log_debug "Getting PRs from last $days days (limit: $limit)..."
    
    local state_filter="all"
    if [ "$include_closed" = false ]; then
        state_filter="open"
    fi
    
    # Calculate date threshold
    local date_threshold
    if command -v gdate &> /dev/null; then
        # macOS with GNU date
        date_threshold=$(gdate -d "$days days ago" -u +"%Y-%m-%dT%H:%M:%SZ")
    else
        # Linux with GNU date
        date_threshold=$(date -d "$days days ago" -u +"%Y-%m-%dT%H:%M:%SZ")
    fi
    
    log_debug "Date threshold: $date_threshold"
    
    # Get PRs and filter by date
    gh api "repos/$owner/$repo/pulls" \
        --paginate \
        -f state="$state_filter" \
        -F per_page=100 \
        --jq --arg threshold "$date_threshold" --arg limit "$limit" \
        '[.[] | select(.created_at >= $threshold)] | sort_by(.created_at) | reverse | .[:($limit | tonumber)]'
}

# Function to extract suggestions from a single PR
extract_pr_suggestions() {
    local owner="$1"
    local repo="$2"
    local pr_number="$3"
    
    log_debug "Extracting suggestions from PR #$pr_number..."
    
    # Get all review comments for this PR
    local comments
    comments=$(gh api "repos/$owner/$repo/pulls/$pr_number/comments" --paginate 2>/dev/null)
    
    if [ -z "$comments" ] || [ "$comments" = "[]" ]; then
        echo "[]"
        return
    fi
    
    # Filter and enrich suggestion comments
    echo "$comments" | jq --arg pr "$pr_number" '[.[] | select(.body | test("```suggestion\\s*\\n.*\\n```"; "ms")) | {
        pr_number: ($pr | tonumber),
        id: .id,
        user: .user.login,
        body: .body,
        path: .path,
        position: .position,
        line: .line,
        original_line: .original_line,
        commit_id: .commit_id,
        created_at: .created_at,
        updated_at: .updated_at,
        url: .html_url,
        suggestion_content: (.body | capture("```suggestion\\s*\\n(?<content>.*?)\\n```"; "ms").content),
        description: (.body | split("```suggestion")[0] | rtrimstr("\n") | ltrimstr("\n")),
        suggestion_lines: (.body | capture("```suggestion\\s*\\n(?<content>.*?)\\n```"; "ms").content | split("\n") | length),
        has_description: (.body | split("```suggestion")[0] | rtrimstr("\n") | ltrimstr("\n") | length > 0),
        file_extension: (.path | split(".") | .[-1] // "unknown")
    }]'
}

# Function to get all suggestions from multiple PRs
get_all_suggestions() {
    local owner="$1"
    local repo="$2"
    local prs="$3"
    
    log_info "Extracting suggestions from $(echo "$prs" | jq 'length') PRs..."
    
    local all_suggestions="[]"
    local count=0
    
    # Process each PR
    echo "$prs" | jq -r '.[].number' | while read -r pr_number; do
        count=$((count + 1))
        log_debug "Processing PR #$pr_number ($count/$(echo "$prs" | jq 'length'))..."
        
        local pr_suggestions
        pr_suggestions=$(extract_pr_suggestions "$owner" "$repo" "$pr_number")
        
        # Merge with all suggestions
        all_suggestions=$(echo "$all_suggestions $pr_suggestions" | jq -s 'add')
        
        # Rate limiting - small delay
        sleep 0.1
    done
    
    echo "$all_suggestions"
}

# Function to analyze specific PR
cmd_pr_analysis() {
    local owner="$1"
    local repo="$2"
    
    if [ -z "$PR_NUMBER" ]; then
        log_error "PR number is required for pr-analysis. Use --pr option."
        exit 1
    fi
    
    log_info "Analyzing suggestions in PR #$PR_NUMBER..."
    
    # Get PR info
    local pr_info
    pr_info=$(gh api "repos/$owner/$repo/pulls/$PR_NUMBER")
    
    # Extract suggestions
    local suggestions
    suggestions=$(extract_pr_suggestions "$owner" "$repo" "$PR_NUMBER")
    
    # Generate analysis
    local analysis
    analysis=$(echo "$suggestions" | jq --argjson pr_info "$pr_info" '{
        pr_number: $pr_info.number,
        pr_title: $pr_info.title,
        pr_author: $pr_info.user.login,
        pr_state: $pr_info.state,
        pr_created: $pr_info.created_at,
        pr_updated: $pr_info.updated_at,
        analysis: {
            total_suggestions: length,
            unique_contributors: ([.[].user] | unique | length),
            files_affected: ([.[].path] | unique | length),
            total_suggestion_lines: ([.[].suggestion_lines] | add // 0),
            avg_lines_per_suggestion: (([.[].suggestion_lines] | add // 0) / (length | if . == 0 then 1 else . end)),
            suggestions_with_description: ([.[] | select(.has_description)] | length),
            description_rate: (([.[] | select(.has_description)] | length) / (length | if . == 0 then 1 else . end) * 100),
            file_types: ([.[].file_extension] | group_by(.) | map({extension: .[0], count: length})),
            contributors: ([.[].user] | group_by(.) | map({user: .[0], count: length})),
            files: ([.[].path] | group_by(.) | map({file: .[0], count: length})),
            timeline: ([.[] | .created_at[:10]] | group_by(.) | map({date: .[0], count: length}))
        },
        suggestions: .
    }')
    
    # Output based on format
    case "$OUTPUT_FORMAT" in
        "json")
            echo "$analysis"
            ;;
        "csv")
            echo "PR,Title,Author,State,Suggestions,Contributors,Files,Lines,DescriptionRate"
            echo "$analysis" | jq -r '[.pr_number, .pr_title, .pr_author, .pr_state, .analysis.total_suggestions, .analysis.unique_contributors, .analysis.files_affected, .analysis.total_suggestion_lines, (.analysis.description_rate | floor)] | @csv'
            ;;
        *)
            display_pr_analysis "$analysis"
            ;;
    esac
}

# Function to display PR analysis in human format
display_pr_analysis() {
    local analysis="$1"
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                              PR SUGGESTION ANALYSIS                                              ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════════════════════════════${NC}"
    
    echo "$analysis" | jq -r '"
📋 PR Information:
   Number: #\(.pr_number)
   Title: \(.pr_title)
   Author: \(.pr_author)
   State: \(.pr_state | ascii_upcase)
   Created: \(.pr_created[:10])
   Updated: \(.pr_updated[:10])

📊 Suggestion Overview:
   Total Suggestions: \(.analysis.total_suggestions)
   Unique Contributors: \(.analysis.unique_contributors)
   Files Affected: \(.analysis.files_affected)
   Total Lines Suggested: \(.analysis.total_suggestion_lines)
   Average Lines per Suggestion: \(.analysis.avg_lines_per_suggestion | floor)
   Description Rate: \(.analysis.description_rate | floor)%
"'
    
    # Show top contributors
    echo -e "${YELLOW}👥 Top Contributors:${NC}"
    echo "$analysis" | jq -r '.analysis.contributors | sort_by(-.count) | .[:5][] | "   \(.user): \(.count) suggestion(s)"'
    
    echo ""
    
    # Show file types
    echo -e "${YELLOW}📁 File Types:${NC}"
    echo "$analysis" | jq -r '.analysis.file_types | sort_by(-.count) | .[:5][] | "   .\(.extension): \(.count) suggestion(s)"'
    
    echo ""
    
    # Show timeline
    echo -e "${YELLOW}📅 Suggestion Timeline:${NC}"
    echo "$analysis" | jq -r '.analysis.timeline | sort_by(.date) | .[] | "   \(.date): \(.count) suggestion(s)"'
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════════════════════════════${NC}"
}

# Function to analyze repository
cmd_repo_analysis() {
    local owner="$1"
    local repo="$2"
    
    log_info "Performing repository-wide suggestion analysis..."
    log_info "Parameters: last $DAYS_LIMIT days, max $PR_LIMIT PRs"
    
    # Get PRs in range
    local prs
    prs=$(get_prs_in_range "$owner" "$repo" "$DAYS_LIMIT" "$PR_LIMIT" "$INCLUDE_CLOSED")
    
    local pr_count
    pr_count=$(echo "$prs" | jq 'length')
    
    if [ "$pr_count" -eq 0 ]; then
        log_warning "No PRs found in the specified date range"
        return
    fi
    
    log_info "Found $pr_count PRs to analyze"
    
    # Extract all suggestions
    local suggestions="[]"
    local processed=0
    
    echo "$prs" | jq -r '.[].number' | while read -r pr_number; do
        processed=$((processed + 1))
        log_debug "Processing PR #$pr_number ($processed/$pr_count)..."
        
        local pr_suggestions
        pr_suggestions=$(extract_pr_suggestions "$owner" "$repo" "$pr_number")
        
        if [ "$pr_suggestions" != "[]" ]; then
            echo "$pr_suggestions" | jq -c '.[]'
        fi
        
        # Rate limiting
        sleep 0.1
    done | jq -s '.' > /tmp/all_suggestions.json
    
    suggestions=$(cat /tmp/all_suggestions.json)
    rm -f /tmp/all_suggestions.json
    
    # Generate comprehensive analysis
    local analysis
    analysis=$(echo "$suggestions" | jq --argjson prs "$prs" '{
        repository: {
            owner: "'$owner'",
            name: "'$repo'",
            analysis_period: "'$DAYS_LIMIT' days",
            prs_analyzed: ($prs | length),
            prs_with_suggestions: ([.[] | .pr_number] | unique | length)
        },
        overview: {
            total_suggestions: length,
            unique_contributors: ([.[].user] | unique | length),
            files_affected: ([.[].path] | unique | length),
            total_lines_suggested: ([.[].suggestion_lines] | add // 0),
            avg_suggestions_per_pr: (length / (($prs | length) | if . == 0 then 1 else . end)),
            description_rate: (([.[] | select(.has_description)] | length) / (length | if . == 0 then 1 else . end) * 100)
        },
        contributors: ([.[].user] | group_by(.) | map({
            user: .[0], 
            count: length,
            avg_lines: ([.. | select(type == "object" and .user == .[0]) | .suggestion_lines] | add / length)
        }) | sort_by(-.count)),
        file_analysis: {
            by_extension: ([.[].file_extension] | group_by(.) | map({extension: .[0], count: length}) | sort_by(-.count)),
            by_path: ([.[].path] | group_by(.) | map({path: .[0], count: length}) | sort_by(-.count) | .[:10]),
            most_suggested_files: ([.[].path] | group_by(.) | map({file: .[0], count: length}) | sort_by(-.count) | .[:5])
        },
        temporal_analysis: {
            by_day: ([.[] | .created_at[:10]] | group_by(.) | map({date: .[0], count: length}) | sort_by(.date)),
            by_week: ([.[] | .created_at[:7]] | group_by(.) | map({week: .[0], count: length}) | sort_by(.week)),
            trend_data: ([.[] | .created_at[:10]] | group_by(.) | map(.date) | sort)
        },
        quality_metrics: {
            suggestions_with_description: ([.[] | select(.has_description)] | length),
            avg_suggestion_length: ([.[].suggestion_lines] | add / length),
            single_line_suggestions: ([.[] | select(.suggestion_lines == 1)] | length),
            multi_line_suggestions: ([.[] | select(.suggestion_lines > 1)] | length)
        }
    }')
    
    # Output based on format
    case "$OUTPUT_FORMAT" in
        "json")
            echo "$analysis"
            ;;
        "csv")
            echo "Metric,Value"
            echo "$analysis" | jq -r '.overview | to_entries[] | [.key, .value] | @csv'
            ;;
        *)
            display_repo_analysis "$analysis"
            ;;
    esac
}

# Function to display repository analysis
display_repo_analysis() {
    local analysis="$1"
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                           REPOSITORY SUGGESTION ANALYSIS                                         ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════════════════════════════${NC}"
    
    echo "$analysis" | jq -r '"
🏗️  Repository: \(.repository.owner)/\(.repository.name)
📅 Analysis Period: \(.repository.analysis_period)
📊 PRs Analyzed: \(.repository.prs_analyzed)
📋 PRs with Suggestions: \(.repository.prs_with_suggestions)

📈 Overview Metrics:
   Total Suggestions: \(.overview.total_suggestions)
   Unique Contributors: \(.overview.unique_contributors)
   Files Affected: \(.overview.files_affected)
   Total Lines Suggested: \(.overview.total_lines_suggested)
   Average Suggestions per PR: \(.overview.avg_suggestions_per_pr | floor)
   Description Rate: \(.overview.description_rate | floor)%
"'
    
    echo -e "${YELLOW}👑 Top Contributors:${NC}"
    echo "$analysis" | jq -r '.contributors[:5][] | "   \(.user): \(.count) suggestions (avg \(.avg_lines | floor) lines)"'
    
    echo ""
    echo -e "${YELLOW}📁 File Type Distribution:${NC}"
    echo "$analysis" | jq -r '.file_analysis.by_extension[:5][] | "   .\(.extension): \(.count) suggestions"'
    
    echo ""
    echo -e "${YELLOW}🎯 Most Suggested Files:${NC}"
    echo "$analysis" | jq -r '.file_analysis.most_suggested_files[] | "   \(.file): \(.count) suggestions"'
    
    echo ""
    echo -e "${YELLOW}📊 Quality Metrics:${NC}"
    echo "$analysis" | jq -r '"   Suggestions with Description: \(.quality_metrics.suggestions_with_description)
   Average Suggestion Length: \(.quality_metrics.avg_suggestion_length | floor) lines
   Single-line Suggestions: \(.quality_metrics.single_line_suggestions)
   Multi-line Suggestions: \(.quality_metrics.multi_line_suggestions)"'
    
    echo ""
    echo -e "${YELLOW}📅 Recent Activity (Last 7 Days):${NC}"
    echo "$analysis" | jq -r '.temporal_analysis.by_day[-7:][] | "   \(.date): \(.count) suggestions"'
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════════════════════════════${NC}"
}

# Function to analyze user patterns
cmd_user_analysis() {
    local owner="$1"
    local repo="$2"
    
    if [ -z "$USER_FILTER" ]; then
        log_error "User is required for user-analysis. Use --user option."
        exit 1
    fi
    
    log_info "Analyzing suggestion patterns for user: $USER_FILTER"
    
    # Get PRs and extract suggestions
    local prs
    prs=$(get_prs_in_range "$owner" "$repo" "$DAYS_LIMIT" "$PR_LIMIT" "$INCLUDE_CLOSED")
    
    # Process suggestions for the specific user
    local user_suggestions="[]"
    echo "$prs" | jq -r '.[].number' | while read -r pr_number; do
        local pr_suggestions
        pr_suggestions=$(extract_pr_suggestions "$owner" "$repo" "$pr_number")
        
        # Filter by user
        echo "$pr_suggestions" | jq --arg user "$USER_FILTER" '.[] | select(.user == $user)' | jq -c '.'
        
        sleep 0.1
    done | jq -s '.' > /tmp/user_suggestions.json
    
    user_suggestions=$(cat /tmp/user_suggestions.json)
    rm -f /tmp/user_suggestions.json
    
    # Generate user analysis
    local analysis
    analysis=$(echo "$user_suggestions" | jq '{
        user: "'$USER_FILTER'",
        period: "'$DAYS_LIMIT' days",
        summary: {
            total_suggestions: length,
            unique_prs: ([.[].pr_number] | unique | length),
            unique_files: ([.[].path] | unique | length),
            total_lines: ([.[].suggestion_lines] | add // 0),
            avg_lines_per_suggestion: (([.[].suggestion_lines] | add // 0) / (length | if . == 0 then 1 else . end)),
            description_rate: (([.[] | select(.has_description)] | length) / (length | if . == 0 then 1 else . end) * 100)
        },
        patterns: {
            file_types: ([.[].file_extension] | group_by(.) | map({extension: .[0], count: length}) | sort_by(-.count)),
            files_suggested: ([.[].path] | group_by(.) | map({file: .[0], count: length}) | sort_by(-.count)),
            prs_contributed: ([.[].pr_number] | group_by(.) | map({pr: .[0], count: length}) | sort_by(-.count)),
            activity_timeline: ([.[] | .created_at[:10]] | group_by(.) | map({date: .[0], count: length}) | sort_by(.date))
        },
        quality: {
            single_line_count: ([.[] | select(.suggestion_lines == 1)] | length),
            multi_line_count: ([.[] | select(.suggestion_lines > 1)] | length),
            with_description: ([.[] | select(.has_description)] | length),
            without_description: ([.[] | select(.has_description | not)] | length)
        }
    }')
    
    case "$OUTPUT_FORMAT" in
        "json")
            echo "$analysis"
            ;;
        *)
            display_user_analysis "$analysis"
            ;;
    esac
}

# Function to display user analysis
display_user_analysis() {
    local analysis="$1"
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                               USER SUGGESTION ANALYSIS                                           ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════════════════════════════${NC}"
    
    echo "$analysis" | jq -r '"
👤 User: \(.user)
📅 Period: \(.period)

📊 Summary:
   Total Suggestions: \(.summary.total_suggestions)
   PRs Contributed To: \(.summary.unique_prs)
   Files Suggested: \(.summary.unique_files)
   Total Lines: \(.summary.total_lines)
   Average Lines per Suggestion: \(.summary.avg_lines_per_suggestion | floor)
   Description Rate: \(.summary.description_rate | floor)%
"'
    
    echo -e "${YELLOW}💡 Suggestion Patterns:${NC}"
    echo "$analysis" | jq -r '"   Preferred File Types: \(.patterns.file_types[:3] | map("\(.extension) (\(.count))") | join(", "))
   Most Active PRs: \(.patterns.prs_contributed[:3] | map("#\(.pr) (\(.count))") | join(", "))"'
    
    echo ""
    echo -e "${YELLOW}📁 Top Files Suggested:${NC}"
    echo "$analysis" | jq -r '.patterns.files_suggested[:5][] | "   \(.file): \(.count) suggestions"'
    
    echo ""
    echo -e "${YELLOW}📊 Quality Breakdown:${NC}"
    echo "$analysis" | jq -r '"   Single-line Suggestions: \(.quality.single_line_count)
   Multi-line Suggestions: \(.quality.multi_line_count)
   With Description: \(.quality.with_description)
   Without Description: \(.quality.without_description)"'
    
    echo ""
    echo -e "${YELLOW}📅 Activity Timeline:${NC}"
    echo "$analysis" | jq -r '.patterns.activity_timeline[] | "   \(.date): \(.count) suggestions"'
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════════════════════════════${NC}"
}

# Function to generate comprehensive export report
cmd_export_report() {
    local owner="$1"
    local repo="$2"
    
    log_info "Generating comprehensive suggestion report..."
    
    case "$OUTPUT_FORMAT" in
        "html")
            generate_html_report "$owner" "$repo"
            ;;
        "markdown")
            generate_markdown_report "$owner" "$repo"
            ;;
        *)
            log_error "Export format $OUTPUT_FORMAT not supported for comprehensive reports"
            log_info "Supported formats: html, markdown"
            exit 1
            ;;
    esac
}

# Function to generate HTML report
generate_html_report() {
    local owner="$1"
    local repo="$2"
    
    local report_file="${OUTPUT_FILE:-suggestion_report_$(date +%Y%m%d_%H%M%S).html}"
    
    log_info "Generating HTML report: $report_file"
    
    # Get repository analysis data
    local prs
    prs=$(get_prs_in_range "$owner" "$repo" "$DAYS_LIMIT" "$PR_LIMIT" "$INCLUDE_CLOSED")
    
    # Generate comprehensive data (simplified for space)
    cat > "$report_file" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>GitHub PR Suggestions Analysis Report</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; margin: 0; padding: 20px; background: #f6f8fa; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        .header { text-align: center; border-bottom: 2px solid #e1e4e8; padding-bottom: 20px; margin-bottom: 30px; }
        .metric-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }
        .metric-card { background: #f6f8fa; padding: 20px; border-radius: 6px; border-left: 4px solid #0366d6; }
        .metric-value { font-size: 2em; font-weight: bold; color: #0366d6; }
        .metric-label { color: #586069; margin-top: 5px; }
        .section { margin: 30px 0; }
        .section h2 { color: #24292e; border-bottom: 1px solid #e1e4e8; padding-bottom: 10px; }
        table { width: 100%; border-collapse: collapse; margin: 15px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #e1e4e8; }
        th { background: #f6f8fa; font-weight: 600; }
        .progress-bar { width: 100%; height: 8px; background: #e1e4e8; border-radius: 4px; overflow: hidden; }
        .progress-fill { height: 100%; background: #28a745; transition: width 0.3s ease; }
        .footer { text-align: center; margin-top: 40px; padding-top: 20px; border-top: 1px solid #e1e4e8; color: #586069; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📊 GitHub PR Suggestions Analysis</h1>
            <p><strong>Repository:</strong> OWNER/REPO | <strong>Generated:</strong> REPORT_DATE</p>
        </div>
        
        <div class="section">
            <h2>📈 Overview Metrics</h2>
            <div class="metric-grid">
                <div class="metric-card">
                    <div class="metric-value">0</div>
                    <div class="metric-label">Total Suggestions</div>
                </div>
                <div class="metric-card">
                    <div class="metric-value">0</div>
                    <div class="metric-label">Contributors</div>
                </div>
                <div class="metric-card">
                    <div class="metric-value">0</div>
                    <div class="metric-label">Files Affected</div>
                </div>
                <div class="metric-card">
                    <div class="metric-value">0%</div>
                    <div class="metric-label">Description Rate</div>
                </div>
            </div>
        </div>
        
        <div class="footer">
            <p>Generated by GitHub PR Suggestion Analyzer | <em>Data reflects last DAYS_LIMIT days</em></p>
        </div>
    </div>
</body>
</html>
EOF

    # Replace placeholders
    sed -i "s/OWNER/$owner/g" "$report_file"
    sed -i "s/REPO/$repo/g" "$report_file"
    sed -i "s/REPORT_DATE/$(date)/g" "$report_file"
    sed -i "s/DAYS_LIMIT/$DAYS_LIMIT/g" "$report_file"
    
    log_success "HTML report generated: $report_file"
}

# Function to parse command line arguments
parse_args() {
    if [ $# -lt 3 ]; then
        log_error "Invalid number of arguments"
        usage
    fi
    
    COMMAND="$1"
    OWNER="$2"
    REPO="$3"
    shift 3
    
    while [ $# -gt 0 ]; do
        case "$1" in
            --pr)
                shift
                PR_NUMBER="$1"
                ;;
            --user)
                shift
                USER_FILTER="$1"
                ;;
            --pattern)
                shift
                FILE_PATTERN="$1"
                ;;
            --days)
                shift
                DAYS_LIMIT="$1"
                ;;
            --limit)
                shift
                PR_LIMIT="$1"
                ;;
            --format)
                shift
                OUTPUT_FORMAT="$1"
                ;;
            --output)
                shift
                OUTPUT_FILE="$1"
                ;;
            --open-only)
                INCLUDE_CLOSED=false
                ;;
            --verbose)
                VERBOSE=true
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
        shift
    done
    
    # Validate command
    case "$COMMAND" in
        pr-analysis|repo-analysis|user-analysis|file-analysis|trend-analysis|team-metrics|export-report)
            ;;
        *)
            log_error "Invalid command: $COMMAND"
            usage
            ;;
    esac
    
    # Validate numeric parameters
    if [[ ! "$DAYS_LIMIT" =~ ^[0-9]+$ ]]; then
        log_error "Days limit must be a positive integer"
        exit 1
    fi
    
    if [[ ! "$PR_LIMIT" =~ ^[0-9]+$ ]]; then
        log_error "PR limit must be a positive integer"
        exit 1
    fi
}

# Main function
main() {
    parse_args "$@"
    
    # Check dependencies and authentication
    check_dependencies
    check_auth
    
    # Execute command
    case "$COMMAND" in
        pr-analysis)
            cmd_pr_analysis "$OWNER" "$REPO"
            ;;
        repo-analysis)
            cmd_repo_analysis "$OWNER" "$REPO"
            ;;
        user-analysis)
            cmd_user_analysis "$OWNER" "$REPO"
            ;;
        export-report)
            cmd_export_report "$OWNER" "$REPO"
            ;;
        *)
            log_error "Command $COMMAND not yet implemented"
            ;;
    esac
}

# Run main function with all arguments
main "$@"