# GitHub CLI Automation Toolkit

> **MCP Server Implementation Welcome!** 🚀  
> Author found CLI tools sufficient for agent workflows, but would be happy to implement an MCP server based on this toolkit. Please [file an issue](../../issues) if you'd like MCP server support!

Collection of tested scripts and examples for automating GitHub workflows using GitHub CLI and GraphQL API. Built from real-world usage and experimentation.

## 🚀 Quick Start

```bash
# Authentication setup
gh auth login --scopes "project"

# Test basic functionality
./github-projects-item-management.sh --help
```

## 📚 Documentation

### Quick Start Guides
- **[Getting Started](GETTING-STARTED.md)** - Setup and first steps
- **[Scripts Reference](SCRIPTS-REFERENCE.md)** - Command reference for all scripts
- **[Production Guide](PRODUCTION-GUIDE.md)** - Deployment best practices
- **[Features](FEATURES.md)** - Implemented and tested features
- **[Roadmap](ROADMAP.md)** - Development milestones and future considerations

### Core Features
- **[GitHub Projects](github-projects-overview.md)** - Projects v2 automation overview
- **[GitHub Sub-Issues](github-sub-issues/)** - Native hierarchical issue management
- **[Labels Management](labels-management-automation.md)** - Automated label operations

### Detailed Guides
- **[Projects Basic Usage](github-projects-basic-usage.md)** - Essential CLI commands
- **[Custom Fields Management](github-projects-custom-fields.md)** - Kanban automation
- **[Automation Scripts](github-projects-automation-scripts.md)** - Production examples

### API Integration
- **[CLI/API Examples](github-cli-api-code-snippets-samples-examples/)** - GraphQL and REST examples

## 🛠️ Tools

### Executable Scripts
- `github-projects-item-management.sh` - Issues ↔ Projects CRUD
- `github-projects-field-discovery.sh` - Field inspection  
- `github-projects-field-management.sh` - Field value operations
- `github-sub-issues-query.sh` - Sub-issue relationships (read)
- `github-sub-issues-crud.sh` - Sub-issue relationships (write)

### Python Alternatives
- `github_projects_automation.py` - Complete Python implementation
- `github_sub_issues.py` - Sub-issues Python toolkit

## 📖 Key Capabilities

| Feature | Description | Status |
|---------|-------------|--------|
| **Projects v2** | Issues ↔ Projects, field management | ✅ Tested |
| **Sub-Issues** | Parent-child relationships (beta API) | ✅ Tested |
| **Custom Fields** | Status, Priority field automation | ✅ Tested |
| **Bulk Operations** | CSV workflows, batch processing | ✅ Tested |
| **Error Handling** | Retry logic, validation | ✅ Implemented |

## 🎯 Use Cases

Based on testing and development experience:

- **Project board automation** - Tested with Issues ↔ Projects workflows
- **Bulk issue management** - Validated CSV import/export operations  
- **Custom field automation** - Status, Priority field management tested
- **Sub-issues workflows** - Hierarchical issue relationship management

**Need a feature?** Please [request it](../../issues) - we're happy to extend based on real use cases!

## 📋 Requirements

- GitHub CLI (`gh`) with project scope
- Bash 4.0+ or Python 3.7+
- GitHub Personal Access Token with project permissions

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
2. **Reference**: Check [Scripts Reference](SCRIPTS-REFERENCE.md) for all commands
3. **Deploy**: See [Production Guide](PRODUCTION-GUIDE.md) for deployment considerations
4. **Integrate**: Adapt scripts for your workflows

---

**All content anonymized and production-ready** 🛡️