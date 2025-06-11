# GitHub Sub-Issues Overview

GitHub's native sub-issues feature enables hierarchical issue relationships for breaking down complex work.

## Key Features

- **Hierarchical Structure** - Up to 8 levels of nesting
- **Scale** - 100 sub-issues per parent issue
- **Project Integration** - Sub-issues appear in project views
- **Progress Tracking** - Automatic parent-child relationship visibility
- **Filtering** - Group and filter by parent issue

## Creating Sub-Issues

**New sub-issue:**
1. Open parent issue → "Create sub-issue"
2. Add title, description, assignees, labels
3. Click "Create"

**Existing issue as sub-issue:**
1. Parent issue → dropdown next to "Create sub-issue" 
2. Select "Add existing issue"
3. Choose from suggestions or search

## Current Limitations

- **Beta feature** - UI only, no CLI support
- **Permissions** - Requires triage access
- **No API automation** - Manual relationship creation only

## CLI Status

No direct CLI commands available yet. Standard issue creation works:

```bash
# Create issues normally
gh issue create --title "Parent Epic"
gh issue create --title "Child Task"

# Manual step: Use GitHub UI to create sub-issue relationship
```

## Reference

📖 [GitHub Docs: Adding sub-issues](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/adding-sub-issues)