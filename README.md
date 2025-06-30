# GitHub CLI Automation Toolkit

> **MCP Server Implementation Welcome!** 🚀  
> Author found CLI tools sufficient for agent workflows, but would be happy to implement an MCP server based on this toolkit. Please [file an issue](../../issues) if you'd like MCP server support!

Collection of tested scripts and examples for automating GitHub workflows using GitHub CLI and GraphQL API. Built from real-world usage and experimentation.

## ⚠️ CRITICAL: Authentication Requirements

**GitHub Projects v2 API requires CLASSIC personal access tokens with 'project' scope.**

**❌ Fine-grained personal access tokens (new tokens) do NOT work with Projects v2 API**  
**✅ Classic personal access tokens from ${GITHUB_TOKEN_DOTFILE} work perfectly**

### Quick Setup

```bash
# Option 1: Use classic token environment file (RECOMMENDED)
source "${GITHUB_TOKEN_DOTFILE}"
export GH_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN"

# Option 2: Interactive authentication (may not set project scopes correctly)
gh auth login --scopes "project"

# Test authentication works
gh project list --owner @me
```

## 🚀 Quick Start

```bash
# Authentication setup (use classic token)
source "${GITHUB_TOKEN_DOTFILE}" && export GH_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN"

# Test basic functionality
./github-projects-item-management.sh --help
```

## 📚 Documentation

### Quick Start Guides
- **[Getting Started](GETTING-STARTED.md)** - Setup and first steps
- **[Scripts Reference](SCRIPTS-REFERENCE.md)** - Command reference for all scripts
- **[Command Reference](COMMAND-REFERENCE.md)** - Complete command syntax and options
- **[User Stories](USER-STORIES.md)** - Practical workflow examples and use cases
- **[Production Guide](PRODUCTION-GUIDE.md)** - Deployment best practices
- **[Features](FEATURES.md)** - Implemented and tested features
- **[Roadmap](ROADMAP.md)** - Development milestones and future considerations

### Core Features
- **[GitHub Projects](github-projects-overview.md)** - Projects v2 automation overview
- **[GitHub Sub-Issues](github-sub-issues/)** - Native hierarchical issue management
- **[PR Comments Management](github-pr-comments-edit-vs-reply-guide.md)** - Edit vs Reply comment operations
- **[Labels Management](labels-management-automation.md)** - Automated label operations

### Detailed Guides
- **[Projects Basic Usage](github-projects-basic-usage.md)** - Essential CLI commands
- **[Custom Fields Management](github-projects-custom-fields.md)** - Kanban automation
- **[Automation Scripts](github-projects-automation-scripts.md)** - Production examples

### API Integration
- **[CLI/API Examples](github-cli-api-code-snippets-samples-examples/)** - GraphQL and REST examples

### PR Comment Management
- **[Edit vs Reply Guide](github-pr-comments-edit-vs-reply-guide.md)** - **CRITICAL**: Understanding edit vs reply operations
- **[PR Comments API Guide](github-pr-review-comments-api-guide.md)** - Complete API reference
- **[PR Comments Scripts](github-pr-review-comments-scripts/)** - Automated comment management tools

## 🛠️ Tools

### Executable Scripts
- `github-projects-item-management.sh` - Issues ↔ Projects CRUD
- `github-projects-field-discovery.sh` - Field inspection  
- `github-projects-field-management.sh` - Field value operations
- `github-sub-issues-query.sh` - Sub-issue relationships (read)
- `github-sub-issues-crud.sh` - Sub-issue relationships (write)

### PR Comment Management Scripts
- `github-pr-review-comments-scripts/edit-comment.sh` - **EDIT** existing comment content
- `github-pr-review-comments-scripts/reply-to-comment.sh` - **REPLY** to comments (create new)
- `github-pr-review-comments-scripts/filtered-comment-reader.sh` - Advanced comment filtering
- `github-pr-review-comments-scripts/comment-exporter.sh` - Export comments to multiple formats

### Python Alternatives
- `github_projects_automation.py` - Complete Python implementation
- `github_sub_issues.py` - Sub-issues Python toolkit

## 📖 Key Capabilities

| Feature | Description | Status |
|---------|-------------|--------|
| **Projects v2** | Issues ↔ Projects, field management | ✅ Tested |
| **Sub-Issues** | Parent-child relationships (beta API) | ✅ Tested |
| **PR Comments** | Edit existing vs Reply to comments | ✅ Implemented |
| **Custom Fields** | Status, Priority field automation | ✅ Tested |
| **Bulk Operations** | CSV workflows, batch processing | ✅ Tested |
| **Error Handling** | Retry logic, validation | ✅ Implemented |

## 🎯 Use Cases

Based on testing and development experience:

- **Project board automation** - Tested with Issues ↔ Projects workflows
- **Bulk issue management** - Validated CSV import/export operations  
- **Custom field automation** - Status, Priority field management tested
- **Sub-issues workflows** - Hierarchical issue relationship management
- **PR comment management** - Edit vs reply operations with safety validations

**Need a feature?** Please [request it](../../issues) - we're happy to extend based on real use cases!

## 📋 Requirements

- GitHub CLI (`gh`) with project scope
- Bash 4.0+ or Python 3.7+
- **GitHub Classic Personal Access Token with project permissions** (⚠️ Fine-grained tokens do NOT work)

## 🚨 Troubleshooting

### Common Issues & Solutions

**❌ Empty/Null Projects API Responses**

This is the most common issue - caused by using fine-grained tokens instead of classic tokens:

```bash
# WRONG: Fine-grained token (causes empty responses)
source "${GITHUB_TOKEN_DOTFILE}.finegrained"  # Example of problematic token
export GH_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN"
gh project list --owner @me  # Returns empty

# CORRECT: Classic token 
source "${GITHUB_TOKEN_DOTFILE}"
export GH_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN" 
gh project list --owner @me  # Works perfectly
```

**Authentication Problems**

```bash
# Use classic token (REQUIRED for Projects v2)
source "${GITHUB_TOKEN_DOTFILE}"
export GH_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN"

# Alternative: Re-authenticate with correct scopes (may not work reliably)
gh auth login --scopes "project"

# Verify authentication
gh auth status
```

**Token Type Issues**

- **Classic Personal Access Tokens**: ✅ Work with Projects v2 API
- **Fine-grained Personal Access Tokens**: ❌ Do NOT work (return empty responses)
- **GitHub CLI auth**: ❌ May not set project scopes correctly

**Permission Errors**

- Ensure you have write access to the project/repository
- Check that you're using the correct owner/organization name
- Verify project number exists: `gh project list --owner @me`

**Command Not Found**

```bash
# Make scripts executable
chmod +x *.sh

# Check script location
ls -la github-projects-*.sh
```

**API Rate Limits**

```bash
# Check current rate limits
gh api rate_limit

# Add delays between bulk operations
./script.sh command --verbose  # Monitor rate limit usage
```

**Field/Item Not Found**

```bash
# List available fields
./github-projects-field-discovery.sh list-fields 1 "@me"

# List project items with IDs
./github-projects-item-management.sh list-items 1 "@me" csv
```

For detailed troubleshooting and debugging tips, see [COMMAND-REFERENCE.md](COMMAND-REFERENCE.md#-error-handling).

## 🔗 Technical Reports

- **[Projects Report](GITHUB_PROJECTS_AUTOMATION_REPORT.md)** - Technical implementation details
- **[Sub-Issues Report](GITHUB_SUB_ISSUES_AUTOMATION_REPORT.md)** - Sub-issues API research and testing
- **[Demo Workflow](demo_automation_workflow.sh)** - Working example script

## 🏷️ Output Formats

Scripts support multiple output formats:
- **Table** - Human-readable console output
- **JSON** - Machine-readable structured data  
- **CSV** - Spreadsheet integration
- **Markdown** - Documentation generation

## 🚦 Getting Started

1. **Setup**: Follow [Getting Started Guide](GETTING-STARTED.md)
2. **Commands**: See [Command Reference](COMMAND-REFERENCE.md) for complete syntax
3. **Workflows**: Check [User Stories](USER-STORIES.md) for practical examples
4. **Deploy**: See [Production Guide](PRODUCTION-GUIDE.md) for deployment considerations
5. **Integrate**: Adapt scripts for your workflows

---

**All content anonymized and production-ready** 🛡️