# GitHub Sub-Issues

Materials and documentation for GitHub's native sub-issues feature (beta).

## Overview

GitHub sub-issues provide hierarchical issue relationships with:

- **100 sub-issues** per parent issue
- **8 levels** of nesting depth  
- **Project integration** and filtering
- **Automatic progress tracking**

## Current Status

- **Beta feature** with working CLI support
- **Full CLI automation** available via GraphQL API
- **Complete CRUD operations** supported
- **Requires triage permissions**

## Available Scripts

### Query Operations (`github-sub-issues-query.sh`)

- **list-sub-issues** - List all sub-issues of a parent issue
- **get-parent** - Find parent issue of a sub-issue  
- **show-hierarchy** - Display hierarchical structure with nesting
- **get-issue-info** - Get detailed issue information

### CRUD Operations (`github-sub-issues-crud.sh`)

- **create-sub-issue** - Create parent-child relationship between existing issues
- **create-issue-as-sub** - Create new issue and add as sub-issue
- **remove-sub-issue** - Remove parent-child relationship
- **move-sub-issue** - Move sub-issue from one parent to another
- **prioritize-sub-issue** - Change priority/position of sub-issue
- **convert-to-sub-issue** - Convert standalone issue to sub-issue

## Usage Examples

```bash
# List sub-issues of parent issue #123
./github-sub-issues-query.sh list-sub-issues owner/repo 123

# Create parent-child relationship
./github-sub-issues-crud.sh create-sub-issue --repo owner/repo --parent 123 --child 456

# Create new issue as sub-issue
./github-sub-issues-crud.sh create-issue-as-sub --repo owner/repo --parent 123 --title "New subtask"

# Show complete hierarchy
./github-sub-issues-query.sh show-hierarchy owner/repo 123 --verbose
```

## Reference

- [GitHub Docs: Adding sub-issues](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/adding-sub-issues)