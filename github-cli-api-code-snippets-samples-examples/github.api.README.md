# GitHub CLI/API Code Examples

Practical automation scripts for GitHub CLI and GraphQL API integration.

## Contents

**Core Scripts:**

- `gh_list_issues.py` - Export issues to CSV/SQLite
- `gh_list_repositories.py` - List organization repositories

**WIP Directory - Projects Automation:**

6-step GitHub Projects v2 field management workflow:

1. Get project ID via GraphQL
2. Retrieve kanban field values  
3. Parse field data (Python CSV)
4. Get single select field IDs
5. Extract option IDs (Python CSV)
6. Update field values

Run with: `./run_steps_01_to_04_project_statues_read.sh`

## Usage

```bash
export GITHUB_TOKEN='your_token_here'
```

## Target Audience

DevOps engineers, automation engineers, developers automating GitHub project management and CI/CD workflows.

**Technologies:** GitHub CLI, GraphQL API, Python, Bash