#!/bin/bash
#
# GitHub Projects Automation - Complete Workflow Demo
# 
# This script demonstrates the complete automation workflow using all
# the developed scripts together. It shows how to integrate the tools
# for real-world project management automation.
#
# Usage: ./demo_automation_workflow.sh <project_num> <owner>
#

set -e

# Configuration
PROJECT_NUM="${1:-1}"
OWNER="${2:-example-org}"
DEMO_MODE="${3:-dry-run}"  # dry-run or live

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}GitHub Projects Automation Demo${NC}"
echo -e "${BLUE}================================${NC}"
echo
echo -e "${GREEN}Project:${NC} $PROJECT_NUM"
echo -e "${GREEN}Owner:${NC} $OWNER"
echo -e "${GREEN}Mode:${NC} $DEMO_MODE"
echo

# Validate dependencies
echo -e "${YELLOW}Step 1: Validating environment...${NC}"

if ! command -v gh >/dev/null 2>&1; then
    echo -e "${RED}❌ GitHub CLI not installed${NC}"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo -e "${RED}❌ jq not installed${NC}"
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo -e "${RED}❌ Python 3 not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ All dependencies available${NC}"
echo

# Step 2: Discover project schema
echo -e "${YELLOW}Step 2: Discovering project schema...${NC}"

echo -e "${BLUE}2.1 Listing all project fields:${NC}"
"$SCRIPT_DIR/github-projects-field-discovery.sh" list-fields "$PROJECT_NUM" "$OWNER" 2>/dev/null || {
    echo -e "${YELLOW}⚠️ Cannot access project (authentication/scope issue)${NC}"
    echo -e "${BLUE}ℹ This is expected without proper project scope${NC}"
}

echo
echo -e "${BLUE}2.2 Exporting project schema (JSON):${NC}"
"$SCRIPT_DIR/github-projects-field-discovery.sh" export-schema "$PROJECT_NUM" "$OWNER" json "demo_schema.json" 2>/dev/null || {
    echo -e "${YELLOW}⚠️ Schema export failed (authentication required)${NC}"
    
    # Create sample schema for demo
    cat > demo_schema.json << 'EOF'
{
  "project": {
    "number": 1,
    "owner": "example-org",
    "fields": [
      {
        "id": "PVTSSF_lADOExample123456789",
        "name": "Status",
        "data_type": "SINGLE_SELECT",
        "options": [
          {"id": "abc12345", "name": "Todo"},
          {"id": "def67890", "name": "In Progress"},
          {"id": "ghi11111", "name": "Done"}
        ]
      },
      {
        "id": "PVTSSF_lADOExample987654321",
        "name": "Priority",
        "data_type": "SINGLE_SELECT",
        "options": [
          {"id": "jkl22222", "name": "Low"},
          {"id": "mno33333", "name": "Medium"},
          {"id": "pqr44444", "name": "High"}
        ]
      }
    ]
  }
}
EOF
    echo -e "${GREEN}✅ Created sample schema for demo: demo_schema.json${NC}"
}

echo

# Step 3: List current project items
echo -e "${YELLOW}Step 3: Analyzing current project state...${NC}"

echo -e "${BLUE}3.1 Listing project items:${NC}"
"$SCRIPT_DIR/github-projects-item-management.sh" list-items "$PROJECT_NUM" "$OWNER" 2>/dev/null || {
    echo -e "${YELLOW}⚠️ Cannot list items (authentication required)${NC}"
    echo -e "${BLUE}ℹ With proper authentication, this would show all project items${NC}"
}

echo
echo -e "${BLUE}3.2 Python alternative - listing items:${NC}"
python3 "$SCRIPT_DIR/github_projects_automation.py" list-items "$PROJECT_NUM" "$OWNER" 2>/dev/null || {
    echo -e "${YELLOW}⚠️ Python API call failed (authentication required)${NC}"
    echo -e "${BLUE}ℹ With proper authentication, this would show detailed item data${NC}"
}

echo

# Step 4: Demonstrate bulk operations (dry-run mode)
echo -e "${YELLOW}Step 4: Demonstrating bulk operations...${NC}"

echo -e "${BLUE}4.1 Bulk add issues (dry-run):${NC}"
if [ -f "$SCRIPT_DIR/example_issue_urls.txt" ]; then
    echo "Would add the following issues:"
    grep -v '^#' "$SCRIPT_DIR/example_issue_urls.txt" | grep -v '^[[:space:]]*$' | while read -r url; do
        echo "  ✓ $url"
    done
else
    echo -e "${YELLOW}⚠️ Example file not found: example_issue_urls.txt${NC}"
fi

echo
echo -e "${BLUE}4.2 Bulk field updates (dry-run):${NC}"
if [ -f "$SCRIPT_DIR/example_bulk_updates.csv" ]; then
    echo "Would update the following fields:"
    tail -n +2 "$SCRIPT_DIR/example_bulk_updates.csv" | while IFS=',' read -r item_id field_name value; do
        echo "  ✓ Item $item_id: $field_name = $value"
    done
else
    echo -e "${YELLOW}⚠️ Example file not found: example_bulk_updates.csv${NC}"
fi

echo

# Step 5: Field validation demo
echo -e "${YELLOW}Step 5: Field validation examples...${NC}"

echo -e "${BLUE}5.1 Validating common field names:${NC}"
for field in "Status" "Priority" "Assignee" "Labels"; do
    echo "  Checking field: $field"
    "$SCRIPT_DIR/github-projects-field-discovery.sh" validate-field "$PROJECT_NUM" "$OWNER" "$field" 2>/dev/null && {
        echo -e "    ${GREEN}✅ Field '$field' exists${NC}"
    } || {
        echo -e "    ${YELLOW}⚠️ Field '$field' not found or inaccessible${NC}"
    }
done

echo

# Step 6: Integration examples
echo -e "${YELLOW}Step 6: Integration workflow examples...${NC}"

echo -e "${BLUE}6.1 Simulated CI/CD integration:${NC}"
cat << 'EOF'
#!/bin/bash
# Example CI/CD integration script

# On new issue creation:
ISSUE_URL="https://github.com/owner/repo/issues/123"

# Add to project
ITEM_ID=$(./github-projects-item-management.sh add-issue 1 orgname "$ISSUE_URL")

# Set initial status  
./github-projects-field-management.sh set-field-by-name 1 orgname "$ITEM_ID" "Status" "Todo"

# Set priority based on labels
if gh issue view "$ISSUE_URL" --json labels | jq -r '.labels[].name' | grep -q "bug"; then
    ./github-projects-field-management.sh set-field-by-name 1 orgname "$ITEM_ID" "Priority" "High"
fi
EOF

echo
echo -e "${BLUE}6.2 Automated triage workflow:${NC}"
cat << 'EOF'
#!/bin/bash
# Automated triage based on issue activity

# Get stale items (no activity in 30 days)
STALE_ITEMS=$(./github-projects-item-management.sh list-items 1 orgname json | \
              jq -r '.[] | select(.updated_at < (now - 30*24*3600)) | .id')

# Move to "Stale" status
for item_id in $STALE_ITEMS; do
    ./github-projects-field-management.sh set-field-by-name 1 orgname "$item_id" "Status" "Stale"
done
EOF

echo

# Step 7: Performance characteristics
echo -e "${YELLOW}Step 7: Performance characteristics...${NC}"

echo -e "${BLUE}7.1 Expected performance:${NC}"
echo "  • Single operations: < 2 seconds"
echo "  • Field discovery: < 3 seconds"  
echo "  • Bulk operations (10 items): < 10 seconds"
echo "  • Rate limiting: 0.5s delay between requests"

echo
echo -e "${BLUE}7.2 Error handling features:${NC}"
echo "  • Automatic retry with exponential backoff"
echo "  • Comprehensive input validation"
echo "  • Graceful authentication failure handling"
echo "  • Detailed error logging"

echo

# Step 8: Authentication setup instructions
echo -e "${YELLOW}Step 8: Authentication setup required...${NC}"

echo -e "${BLUE}8.1 To use these scripts with real data:${NC}"
echo "  1. Set up GitHub CLI authentication:"
echo "     ${YELLOW}gh auth login --scopes project${NC}"
echo
echo "  2. Or refresh existing authentication:"
echo "     ${YELLOW}gh auth refresh -s project --hostname github.com${NC}"
echo
echo "  3. Verify project access:"
echo "     ${YELLOW}gh project view 1 --owner example-org${NC}"

echo
echo -e "${BLUE}8.2 Alternative token setup:${NC}"
echo "  1. Create token at: https://github.com/settings/tokens"
echo "  2. Include scopes: read:project, project"
echo "  3. Set environment variable: export GITHUB_TOKEN=your_token"

echo

# Step 9: Summary and next steps
echo -e "${YELLOW}Step 9: Summary and next steps...${NC}"

echo -e "${BLUE}9.1 Files created in this demo:${NC}"
ls -la "$SCRIPT_DIR"/*.sh "$SCRIPT_DIR"/*.py "$SCRIPT_DIR"/*.txt "$SCRIPT_DIR"/*.csv 2>/dev/null | while read -r line; do
    echo "  $line"
done

echo
echo -e "${BLUE}9.2 Next steps for production use:${NC}"
echo "  ✓ Set up proper GitHub authentication with project scopes"
echo "  ✓ Customize field names and options for your project"
echo "  ✓ Create automation workflows based on your needs"
echo "  ✓ Set up CI/CD integration for automatic project management"
echo "  ✓ Monitor logs and set up alerting for failed operations"

echo
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Demo Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo
echo -e "${BLUE}All scripts are ready for production use once authentication is configured.${NC}"
echo -e "${BLUE}See GITHUB_PROJECTS_AUTOMATION_REPORT.md for complete documentation.${NC}"

# Cleanup
if [ -f "demo_schema.json" ]; then
    echo
    echo -e "${YELLOW}Cleaning up demo files...${NC}"
    rm -f demo_schema.json
    echo -e "${GREEN}✅ Cleanup complete${NC}"
fi