# User Stories & Workflow Examples

Practical workflow examples demonstrating how to use the GitHub CLI automation tools for real-world scenarios.

## 🚀 Project Setup Workflow

**Scenario**: Setting up a new project with standardized fields and initial issues.

### Step 1: Export Existing Project Schema

```bash
# Export schema from a template project
./github-projects-field-discovery.sh export-schema 5 ExampleOrg json > project-template.json

# Review the schema structure
cat project-template.json | jq '.fields[] | {name: .name, type: .data_type}'
```

### Step 2: Bulk Import Issues from Planning

```bash
# Create a file with issue URLs from planning session
cat > new-project-issues.txt << EOF
https://github.com/ExampleOrg/new-product/issues/1
https://github.com/ExampleOrg/new-product/issues/2
https://github.com/ExampleOrg/new-product/issues/3
https://github.com/ExampleOrg/new-product/issues/4
EOF

# Bulk add all issues to the new project
./github-projects-item-management.sh bulk-add 1 ExampleOrg new-project-issues.txt
```

### Step 3: Set Initial Field Values

```bash
# Set priority for critical issues
./github-projects-field-management.sh set-field-by-name 1 ExampleOrg ITEM_ID_1 "Priority" "High"
./github-projects-field-management.sh set-field-by-name 1 ExampleOrg ITEM_ID_2 "Priority" "Medium"

# Set initial status
./github-projects-field-management.sh set-field-by-name 1 ExampleOrg ITEM_ID_1 "Status" "Ready"
```

## 📋 Sprint Planning Workflow

**Scenario**: Planning a 2-week sprint with tasks, estimates, and assignments.

### Step 1: Review Available Issues

```bash
# List all project items with current status
./github-projects-item-management.sh list-items 1 ExampleOrg table

# Export detailed view for planning meeting
./github-projects-item-management.sh list-items 1 ExampleOrg csv > current-backlog.csv
```

### Step 2: Create Sprint Scope with Sub-Issues

```bash
# Create epic for sprint
gh issue create --repo ExampleOrg/project --title "Sprint 15: User Authentication" --body "Epic for sprint 15 user auth features"

# Create sub-issues for the epic
./github-sub-issues-crud.sh create-issue-as-sub --repo ExampleOrg/project --parent 50 --title "Implement login form UI"
./github-sub-issues-crud.sh create-issue-as-sub --repo ExampleOrg/project --parent 50 --title "Add password validation"
./github-sub-issues-crud.sh create-issue-as-sub --repo ExampleOrg/project --parent 50 --title "Integrate with OAuth provider"

# Add epic to project
./github-projects-item-management.sh add-issue 1 ExampleOrg "https://github.com/ExampleOrg/project/issues/50"
```

### Step 3: Bulk Update Sprint Assignments

```bash
# Create CSV for bulk sprint assignment
cat > sprint-15-assignments.csv << EOF
item_id,field_name,value
PVTI_123,Sprint,Sprint 15
PVTI_124,Sprint,Sprint 15
PVTI_125,Sprint,Sprint 15
PVTI_123,Story Points,5
PVTI_124,Story Points,3
PVTI_125,Story Points,8
EOF

# Apply bulk updates
./github-projects-field-management.sh bulk-update 1 ExampleOrg sprint-15-assignments.csv
```

## 🔍 Issue Triage Workflow

**Scenario**: Daily triage of new issues with proper categorization and assignment.

### Step 1: Review New Issues

```bash
# Show project hierarchy to understand current structure
./github-sub-issues-query.sh show-hierarchy ExampleOrg/project 1 --verbose

# Get field information for consistent labeling
./github-projects-field-discovery.sh list-fields 1 ExampleOrg table
```

### Step 2: Categorize and Assign

```bash
# Set bug priority and severity
./github-projects-field-management.sh set-field-by-name 1 ExampleOrg ITEM_ID "Type" "Bug"
./github-projects-field-management.sh set-field-by-name 1 ExampleOrg ITEM_ID "Severity" "High"
./github-projects-field-management.sh set-field-by-name 1 ExampleOrg ITEM_ID "Status" "Triage"

# Convert standalone issue to sub-issue if it's part of larger epic
./github-sub-issues-crud.sh convert-to-sub-issue --repo ExampleOrg/project --parent 45 --issue 67
```

### Step 3: Create Triage Report

```bash
# Export current triage status
./github-projects-item-management.sh list-items 1 ExampleOrg csv > triage-status.csv

# Get detailed field analysis
./github-projects-field-discovery.sh export-schema 1 ExampleOrg markdown > field-usage-report.md
```

## 📊 Cross-Project Reporting

**Scenario**: Generating reports across multiple projects for stakeholder updates.

### Step 1: Collect Data from Multiple Projects

```bash
# Create script to collect from multiple projects
for project in 1 2 3; do
    echo "=== Project $project ===" >> cross-project-report.txt
    ./github-projects-item-management.sh list-items $project ExampleOrg csv >> "project-${project}-items.csv"
done
```

### Step 2: Generate Status Summary

```bash
# Count items by status across projects
echo "Status Summary:" > status-summary.txt
for csv_file in project-*-items.csv; do
    echo "--- $csv_file ---" >> status-summary.txt
    tail -n +2 "$csv_file" | cut -d',' -f4 | sort | uniq -c >> status-summary.txt
done
```

### Step 3: Sub-Issues Progress Tracking

```bash
# Generate hierarchy reports for epics
for epic in 45 67 89; do
    echo "Epic #$epic Hierarchy:" >> epic-progress.txt
    ./github-sub-issues-query.sh show-hierarchy ExampleOrg/project $epic >> epic-progress.txt
    echo "" >> epic-progress.txt
done
```

## 🔄 Release Preparation Workflow

**Scenario**: Preparing for a release by organizing completed work and planning next iteration.

### Step 1: Identify Completed Work

```bash
# Export completed items
./github-projects-item-management.sh list-items 1 ExampleOrg csv | grep "Done" > completed-items.csv

# Check for incomplete sub-issues in completed epics
./github-sub-issues-query.sh list-sub-issues ExampleOrg/project 45 --format json | jq '.nodes[] | select(.state == "OPEN")'
```

### Step 2: Move Items to Next Iteration

```bash
# Bulk update incomplete items to next sprint
cat > next-iteration-updates.csv << EOF
item_id,field_name,value
PVTI_456,Sprint,Sprint 16
PVTI_789,Sprint,Sprint 16
PVTI_012,Status,Backlog
EOF

./github-projects-field-management.sh bulk-update 1 ExampleOrg next-iteration-updates.csv --dry-run
./github-projects-field-management.sh bulk-update 1 ExampleOrg next-iteration-updates.csv
```

### Step 3: Archive and Clean Up

```bash
# Clear completed items from active sprint
./github-projects-field-management.sh clear-field-value 1 ExampleOrg PVTI_123 "Sprint"
./github-projects-field-management.sh clear-field-value 1 ExampleOrg PVTI_124 "Sprint"

# Generate release notes from completed sub-issues
./github-sub-issues-query.sh list-sub-issues ExampleOrg/project 45 csv | grep "CLOSED" > release-features.csv
```

## 🛠️ Automation Best Practices

### Dry Run Everything First

```bash
# Always test bulk operations with dry-run
./github-projects-field-management.sh bulk-update 1 ExampleOrg updates.csv --dry-run

# Use dry-run for CRUD operations on sub-issues
./github-sub-issues-crud.sh create-sub-issue --repo owner/repo --parent 1 --child 2 --dry-run
```

### Use Consistent Naming

```bash
# Standardize field names across projects
./github-projects-field-discovery.sh list-fields 1 ExampleOrg table
./github-projects-field-discovery.sh list-fields 2 ExampleOrg table

# Validate field existence before bulk operations
./github-projects-field-discovery.sh validate-field 1 ExampleOrg "Story Points"
```

### Backup and Version Control

```bash
# Export project state before major changes
./github-projects-field-discovery.sh export-schema 1 ExampleOrg json > "project-1-backup-$(date +%Y%m%d).json"
./github-projects-item-management.sh list-items 1 ExampleOrg csv > "project-1-items-$(date +%Y%m%d).csv"

# Version control your CSV files and scripts
git add *.csv *.sh
git commit -m "Project automation scripts and data for sprint 15"
```

### Error Handling and Recovery

```bash
# Save item IDs before bulk operations
./github-projects-item-management.sh list-items 1 ExampleOrg csv | cut -d',' -f1 > item-ids-backup.txt

# Check for failed operations
echo "Checking for errors in recent operations..."
grep -i "error\|failed" /tmp/github_projects_automation.log

# Recovery: Clear problematic field values
while read -r item_id; do
    ./github-projects-field-management.sh clear-field-value 1 ExampleOrg "$item_id" "Problematic Field" --dry-run
done < item-ids-backup.txt
```

## 🎯 Performance Tips

- **Rate Limiting**: Add delays between bulk operations: `sleep 1`
- **Parallel Processing**: Use `xargs -P 4` for parallel field updates
- **Caching**: Export schemas once and reuse for validation
- **Monitoring**: Check API rate limits with `gh api rate_limit`

## 📈 Metrics and Analytics

```bash
# Project velocity metrics
./github-projects-item-management.sh list-items 1 ExampleOrg csv | awk -F',' 'BEGIN{done=0; total=0} {total++; if($4=="Done") done++} END{print "Velocity: " done/total*100 "%"}'

# Sub-issues completion tracking
./github-sub-issues-query.sh list-sub-issues ExampleOrg/project 45 json | jq '.nodes | length as $total | map(select(.state == "CLOSED")) | length as $closed | "Completion: \($closed)/\($total) (\(($closed/$total)*100|floor)%)"'

# Field usage analytics
./github-projects-field-discovery.sh export-schema 1 ExampleOrg json | jq '.fields[] | {name: .name, options: (.options | length)}'
```