# Command Reference

Complete reference for all commands available in the GitHub CLI automation toolkit.

## 📋 Projects Item Management

### `github-projects-item-management.sh`

**add-issue** `<project_num> <owner> <issue_url>`

Add an issue or pull request to the project.

```bash
./github-projects-item-management.sh add-issue 1 "@me" "https://github.com/owner/repo/issues/123"
```

**remove-item** `<project_num> <owner> <item_id>`

Remove an item from the project by item ID.

```bash
./github-projects-item-management.sh remove-item 1 "@me" PVTI_lADOA1ZjX84AWImYzgJla5U
```

**list-items** `<project_num> <owner> [format]`

List all items in the project.

- Formats: `table` (default), `json`, `csv`

```bash
./github-projects-item-management.sh list-items 1 "@me" json
```

**bulk-add** `<project_num> <owner> <file>`

Add multiple issues from a file (one URL per line).

```bash
./github-projects-item-management.sh bulk-add 1 "@me" example_issue_urls.txt
```

**bulk-remove** `<project_num> <owner> <file>`

Remove multiple items from a file (one item ID per line).

```bash
./github-projects-item-management.sh bulk-remove 1 "@me" item_ids.txt
```

**get-project-id** `<project_num> <owner>`

Get the project ID for a given project number and owner.

```bash
./github-projects-item-management.sh get-project-id 1 "@me"
```

## 🔍 Projects Field Discovery

### `github-projects-field-discovery.sh`

**list-fields** `<project_num> <owner> [format]`

List all fields in the project.

- Formats: `table` (default), `json`, `csv`

```bash
./github-projects-field-discovery.sh list-fields 1 "@me" table
```

**get-field-details** `<project_num> <owner> <field_name> [format]`

Get detailed information about a specific field.

- Formats: `detailed` (default), `json`

```bash
./github-projects-field-discovery.sh get-field-details 1 "@me" "Status" json
```

**export-schema** `<project_num> <owner> [format] [output_file]`

Export complete project field schema.

- Formats: `json` (default), `csv`, `markdown`

```bash
./github-projects-field-discovery.sh export-schema 1 "@me" json schema.json
```

**validate-field** `<project_num> <owner> <field_name> [option_name]`

Validate field existence and optionally an option/iteration.

```bash
./github-projects-field-discovery.sh validate-field 1 "@me" "Status" "Done"
```

**find-field-id** `<project_num> <owner> <field_name>`

Get the field ID for a given field name.

```bash
./github-projects-field-discovery.sh find-field-id 1 "@me" "Priority"
```

**find-option-id** `<project_num> <owner> <field_name> <option_name>`

Get the option ID for a given field and option name.

```bash
./github-projects-field-discovery.sh find-option-id 1 "@me" "Status" "Done"
```

## ⚙️ Projects Field Management

### `github-projects-field-management.sh`

**get-field-value** `<project_num> <owner> <item_id> [field_name]`

Get field value(s) for a project item.

```bash
./github-projects-field-management.sh get-field-value 1 "@me" PVTI_lADOA1ZjX84AWImYzgJla5U "Status"
```

**set-field-by-name** `<project_num> <owner> <item_id> <field_name> <value> [--dry-run]`

Set field value using field name and option/value name.

```bash
./github-projects-field-management.sh set-field-by-name 1 "@me" PVTI_123 "Status" "Done"
```

**set-field-by-id** `<project_num> <owner> <item_id> <field_id> <option_id> [--dry-run]`

Set single-select field value using field ID and option ID.

```bash
./github-projects-field-management.sh set-field-by-id 1 "@me" PVTI_123 PVTF_123 PVTSO_456
```

**clear-field-value** `<project_num> <owner> <item_id> <field_name> [--dry-run]`

Clear/remove field value for a project item.

```bash
./github-projects-field-management.sh clear-field-value 1 "@me" PVTI_123 "Priority"
```

**bulk-update** `<project_num> <owner> <csv_file> [--dry-run]`

Bulk update field values from CSV file.

- CSV format: `item_id,field_name,value`

```bash
./github-projects-field-management.sh bulk-update 1 "@me" example_bulk_updates.csv --dry-run
```

## 🔗 Sub-Issues Query Operations

### `github-sub-issues-query.sh`

**list-sub-issues** `<repo> <issue_number> [--format FORMAT] [--verbose]`

List all sub-issues of a parent issue.

- Formats: `table` (default), `json`, `csv`

```bash
./github-sub-issues-query.sh list-sub-issues owner/repo 123 --format json
```

**get-parent** `<repo> <issue_number> [--format FORMAT] [--verbose]`

Get parent issue of a sub-issue.

```bash
./github-sub-issues-query.sh get-parent owner/repo 456 --format table
```

**show-hierarchy** `<repo> <issue_number> [--format FORMAT] [--verbose]`

Display hierarchical structure with nesting.

```bash
./github-sub-issues-query.sh show-hierarchy owner/repo 123 --verbose
```

**get-issue-info** `<repo> <issue_number> [--format FORMAT] [--verbose]`

Get detailed issue information including sub-issue relationships.

```bash
./github-sub-issues-query.sh get-issue-info owner/repo 123 --format json
```

## 🔨 Sub-Issues CRUD Operations

### `github-sub-issues-crud.sh`

**create-sub-issue** `--repo <repo> --parent <parent_num> --child <child_num> [--dry-run] [--force] [--verbose]`

Create a parent-child relationship between two existing issues.

```bash
./github-sub-issues-crud.sh create-sub-issue --repo owner/repo --parent 123 --child 456
```

**create-issue-as-sub** `--repo <repo> --parent <parent_num> --title <title> [--body <body>] [--dry-run] [--force] [--verbose]`

Create a new issue and add it as a sub-issue to parent.

```bash
./github-sub-issues-crud.sh create-issue-as-sub --repo owner/repo --parent 123 --title "New subtask" --body "Task description"
```

**remove-sub-issue** `--repo <repo> --parent <parent_num> --child <child_num> [--dry-run] [--force] [--verbose]`

Remove parent-child relationship (child becomes standalone).

```bash
./github-sub-issues-crud.sh remove-sub-issue --repo owner/repo --parent 123 --child 456 --force
```

**move-sub-issue** `--repo <repo> --from <from_parent> --to <to_parent> --child <child_num> [--dry-run] [--force] [--verbose]`

Move a sub-issue from one parent to another.

```bash
./github-sub-issues-crud.sh move-sub-issue --repo owner/repo --from 123 --to 789 --child 456
```

**prioritize-sub-issue** `--repo <repo> --parent <parent_num> --child <child_num> --position <position> [--dry-run] [--force] [--verbose]`

Change the priority/position of a sub-issue in parent's list.

```bash
./github-sub-issues-crud.sh prioritize-sub-issue --repo owner/repo --parent 123 --child 456 --position 1
```

**convert-to-sub-issue** `--repo <repo> --parent <parent_num> --issue <issue_num> [--dry-run] [--force] [--verbose]`

Convert existing standalone issue to sub-issue.

```bash
./github-sub-issues-crud.sh convert-to-sub-issue --repo owner/repo --parent 123 --issue 456
```

## 🐍 Python Automation

### `github_projects_automation.py`

**list-items** `<project_num> <owner> [--format FORMAT] [--output FILE]`

List all items in the project.

```bash
python3 github_projects_automation.py list-items 1 "@me" --format json --output items.json
```

**list-fields** `<project_num> <owner> [--format FORMAT] [--output FILE]`

List all fields in the project.

```bash
python3 github_projects_automation.py list-fields 1 "@me" --format table
```

**add-issue** `<project_num> <owner> <issue_url>`

Add an issue or pull request to the project.

```bash
python3 github_projects_automation.py add-issue 1 "@me" "https://github.com/owner/repo/issues/123"
```

**remove-item** `<project_num> <owner> <item_id>`

Remove an item from the project.

```bash
python3 github_projects_automation.py remove-item 1 "@me" PVTI_123
```

**set-field** `<project_num> <owner> <item_id> <field_name> <value> [--dry-run]`

Set field value for an item.

```bash
python3 github_projects_automation.py set-field 1 "@me" PVTI_123 "Status" "Done" --dry-run
```

**bulk-update** `<project_num> <owner> <csv_file> [--dry-run]`

Bulk update field values from CSV file.

```bash
python3 github_projects_automation.py bulk-update 1 "@me" updates.csv --dry-run --verbose
```

**export-schema** `<project_num> <owner> [--format FORMAT] [--output FILE]`

Export project schema.

```bash
python3 github_projects_automation.py export-schema 1 "@me" --format markdown --output schema.md
```

### `github_sub_issues.py`

Python alternative for sub-issues management (commands to be documented when script is available).

## 🎛️ Common Options

### Global Options (All Scripts)

- `--help` - Show detailed usage information
- `--verbose` - Enable detailed logging and progress information
- `--dry-run` - Preview changes without executing (where supported)

### Format Options

- `table` - Human-readable table format (default for most commands)
- `json` - Machine-readable JSON format
- `csv` - Comma-separated values for spreadsheet integration
- `markdown` - Markdown format for documentation

### Output Options

- `--output FILE` - Save output to file (Python scripts)
- Direct redirection: `command > file.txt` (Bash scripts)

## 📁 File Formats

### Issue URLs File (`example_issue_urls.txt`)

```
https://github.com/owner/repo/issues/1
https://github.com/owner/repo/issues/2
https://github.com/owner/repo/pull/3
```

### Bulk Updates CSV (`example_bulk_updates.csv`)

```csv
item_id,field_name,value
PVTI_lADOA1ZjX84AWImYzgJla5U,Status,Done
PVTI_lADOA1ZjX84AWImYzgJla5V,Priority,High
PVTI_lADOA1ZjX84AWImYzgJla5W,Sprint,Sprint 15
```

### Item IDs File (`item_ids.txt`)

```
PVTI_lADOA1ZjX84AWImYzgJla5U
PVTI_lADOA1ZjX84AWImYzgJla5V
PVTI_lADOA1ZjX84AWImYzgJla5W
```

## 🔧 Prerequisites

### Required Tools

- **GitHub CLI** (`gh`) - Must be installed and authenticated
- **jq** - JSON processor for parsing API responses
- **curl** - For direct API calls (backup method)

### Authentication

```bash
# Authenticate with project scope
gh auth login --scopes project

# Verify authentication
gh auth status

# Get auth token for Python scripts
gh auth token
```

### Repository Permissions

- **Projects**: Read/write access to organization or user projects
- **Issues**: Read/write access to repository issues
- **Sub-issues**: Triage permissions for sub-issue management

## 🚨 Error Handling

### Common Issues

1. **Authentication Error**: Run `gh auth login --scopes project`
2. **Permission Denied**: Ensure you have write access to the project/repository
3. **Item Not Found**: Verify item ID using `list-items` command
4. **Field Not Found**: Use `list-fields` to check available fields
5. **Rate Limiting**: Add delays between operations or use `--verbose` to monitor

### Debugging Tips

```bash
# Enable verbose logging
command --verbose

# Check recent operations
tail -f /tmp/github_projects_automation.log

# Validate before bulk operations
command --dry-run

# Check API rate limits
gh api rate_limit
```

## 🔍 Examples Index

For comprehensive workflow examples, see:

- [USER-STORIES.md](USER-STORIES.md) - Complete workflow scenarios
- [SCRIPTS-REFERENCE.md](SCRIPTS-REFERENCE.md) - Quick command reference
- Individual script help: `./script.sh --help`