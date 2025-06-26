# GitHub Projects CLI Automation - Overview

## Key Concepts

**GitHub Projects v2** uses custom fields that are separate from issue properties. Issues added to projects can have additional metadata through custom fields like Status, Priority, Sprint, etc.

**Critical Workflow:**

1. **Project Setup** - Create project with custom fields
2. **Issue Management** - Add/remove issues from projects  
3. **Field Management** - Update custom field values for project items
4. **Automation** - Script workflows for bulk operations

## Authentication Required

```bash
gh auth login --scopes "project"
# or refresh existing
gh auth refresh -s project
```

## Quick Start Commands

```bash
# List your projects
gh project list

# Add issue to project (1 = project number, not project ID)
gh project item-add 1 --owner "@me" --url https://github.com/owner/repo/issues/23

# Update project item status (requires project ID, not project number)
gh project item-edit --id <item-id> --field-id <field-id> --project-id <project-id> --single-select-option-id <option-id>
```

## Key Parameter Types

**Project Number vs Project ID:**

- **Project Number** (`1`, `2`, etc.) - Human-readable number from GitHub UI URLs
  - Used in: `gh project item-add`, `gh project view`, `gh project list`
  - Example: `https://github.com/users/username/projects/1` → use `1`

- **Project ID** (`PVT_kwXXXXXX`) - GitHub's internal identifier  
  - Used in: `gh project item-edit`, GraphQL mutations
  - Get with: `gh project view 1 --owner "@me" --format json | jq '.id'`

## Why Use Projects Over Plain Issues

- **Kanban Views** - Visual workflow management
- **Custom Fields** - Priority, Sprint, Estimates beyond GitHub issue fields
- **Cross-Repository** - Track work across multiple repos
- **Roadmap Views** - Timeline and milestone tracking
- **Automation** - GitHub Actions integration with project events

## Documentation Structure

- `github-projects-basic-usage.md` - Essential commands and workflows
- `github-projects-custom-fields.md` - Field management and automation
- `github-projects-automation-scripts.md` - Production-ready automation examples