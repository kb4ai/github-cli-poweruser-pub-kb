# Scripts Reference

Quick reference for all automation scripts in this toolkit.

## 🏗️ Project Management Scripts

### `github-projects-item-management.sh`
**Issues ↔ Projects CRUD operations**

```bash
# Add issue to project
./github-projects-item-management.sh add-issue 1 "@me" "https://github.com/owner/repo/issues/123"

# Remove item from project  
./github-projects-item-management.sh remove-item 1 "@me" ITEM_ID

# List all project items
./github-projects-item-management.sh list-items 1 "@me" json

# Bulk add issues from file
./github-projects-item-management.sh bulk-add 1 "@me" example_issue_urls.txt
```

### `github-projects-field-discovery.sh`
**Field inspection and schema export**

```bash
# List all project fields
./github-projects-field-discovery.sh list-fields 1 "@me"

# Export project schema
./github-projects-field-discovery.sh export-schema 1 "@me" json

# Get specific field details
./github-projects-field-discovery.sh get-field-details 1 "@me" "Status"
```

### `github-projects-field-management.sh`
**Field value CRUD operations**

```bash
# Set field value by name
./github-projects-field-management.sh set-field-by-name 1 "@me" ITEM_ID "Status" "Done"

# Set field value by ID
./github-projects-field-management.sh set-field-by-id 1 "@me" ITEM_ID FIELD_ID OPTION_ID

# Bulk update from CSV
./github-projects-field-management.sh bulk-update 1 "@me" example_bulk_updates.csv

# Clear field value
./github-projects-field-management.sh clear-field-value 1 "@me" ITEM_ID "Priority"
```

## 🔗 Sub-Issues Scripts

### `github-sub-issues-query.sh`
**Sub-issue relationship queries**

```bash
# List sub-issues of parent
./github-sub-issues-query.sh list-sub-issues owner/repo 123

# Find parent of issue
./github-sub-issues-query.sh get-parent owner/repo 456

# Show hierarchy
./github-sub-issues-query.sh show-hierarchy owner/repo 123 --verbose
```

### `github-sub-issues-crud.sh`
**Sub-issue relationship management**

```bash
# Create sub-issue
./github-sub-issues-crud.sh create-sub-issue owner/repo 123 "Sub-task title" "Description"

# Add existing issue as sub-issue
./github-sub-issues-crud.sh add-sub-issue owner/repo 123 456

# Remove sub-issue relationship
./github-sub-issues-crud.sh remove-sub-issue owner/repo 456

# Move sub-issue to different parent
./github-sub-issues-crud.sh move-sub-issue owner/repo 456 789
```

## 🐍 Python Alternatives

### `github_projects_automation.py`
**Complete Python implementation**

```bash
# All project operations in Python
python3 github_projects_automation.py list-items 1 "@me"
python3 github_projects_automation.py add-issue 1 "@me" "https://github.com/owner/repo/issues/123"

# Enhanced logging and progress tracking
python3 github_projects_automation.py bulk-update 1 "@me" example_bulk_updates.csv --verbose
```

### `github_sub_issues.py`
**Sub-issues Python toolkit**

```bash
# Python sub-issues management
python3 github_sub_issues.py list --repo owner/repo --issue 123
python3 github_sub_issues.py create --repo owner/repo --parent 123 --title "New sub-task"
```

## 🔧 Utility Scripts

### `demo_automation_workflow.sh`
**Complete workflow demonstration**

```bash
# Run full demo with your project
./demo_automation_workflow.sh --project 1 --owner "@me"

# Dry-run mode (no changes made)
./demo_automation_workflow.sh --project 1 --owner "@me" --dry-run
```

## 📊 Output Formats

All scripts support multiple output formats:

```bash
# Table format (default, human-readable)
./script.sh command table

# JSON format (machine-readable)
./script.sh command json

# CSV format (spreadsheet integration) 
./script.sh command csv

# Markdown format (documentation)
./script.sh command markdown
```

## 🛠️ Common Options

All scripts support these standard options:

- `--help` - Show detailed usage information
- `--verbose` - Enable detailed logging
- `--dry-run` - Preview changes without executing
- `[format]` - Output format as positional parameter (table/json/csv/markdown)
- `--output FILE` - Save output to file

## 🚨 Error Handling

Scripts include comprehensive error handling:

- **Automatic retries** with exponential backoff
- **Input validation** for all parameters
- **Clear error messages** with suggested solutions
- **Graceful degradation** when possible

## 📝 Examples Files

- `example_issue_urls.txt` - Sample URLs for bulk operations
- `example_bulk_updates.csv` - Sample CSV for field updates
- See individual script help for more examples