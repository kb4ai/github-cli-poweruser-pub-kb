# Getting Started Guide

## Prerequisites

### 1. GitHub CLI Installation
```bash
# Install GitHub CLI (if not already installed)
# macOS
brew install gh

# Ubuntu/Debian
sudo apt install gh

# Windows
winget install GitHub.cli
```

### 2. Authentication Setup
```bash
# Initial authentication with project scope
gh auth login --scopes "project"

# Or refresh existing authentication
gh auth refresh -s project --hostname github.com

# Verify authentication
gh auth status
```

### 3. Verify Project Access
```bash
# Test basic project access
gh project list --owner "@me"

# If you get permission errors, ensure your token has project scope
gh auth refresh -s project
```

## Quick Test

### 1. Run Demo Workflow
```bash
# Make scripts executable
chmod +x *.sh

# Run complete demo
./demo_automation_workflow.sh
```

### 2. Test Individual Components
```bash
# Test project discovery
./github-projects-field-discovery.sh list-fields 1 "@me"

# Test issue management
./github-projects-item-management.sh list-items 1 "@me"

# Test sub-issues (if you have sub-issues in your projects)
./github-sub-issues-query.sh list-sub-issues owner/repo 123
```

## Common Issues

### Authentication Problems
```bash
# Problem: "Resource not accessible by integration"
# Solution: Add project scope
gh auth refresh -s project --hostname github.com

# Problem: "Could not resolve to a node with the global id"
# Solution: Verify project number and owner
gh project list --owner "your-org"
```

### Permission Errors
- Ensure you have **triage** permissions or higher on the repository
- For organization projects, verify you're a member of the organization
- Check that your token has `project` scope (not just `read:project`)

## Next Steps

1. **Browse Documentation**: Start with [GitHub Projects Overview](github-projects-overview.md)
2. **Explore Examples**: Check [API Code Examples](github-cli-api-code-snippets-samples-examples/)
3. **Try Automation**: Run production scripts from [Automation Scripts](github-projects-automation-scripts.md)
4. **Customize**: Adapt scripts for your specific workflows

## Support

- Check the comprehensive reports for detailed documentation
- Review script help: `./script-name.sh --help`
- Ensure all prerequisites are met before reporting issues