# GitHub Labels Management Automation

## Repository Labels (Issues/PRs)

### `gh` CLI
```bash
# CRUD operations
gh label list [--json name,color,description]
gh label create NAME --description DESC --color HEXCODE
gh label edit NAME --name NEW_NAME --color HEXCODE --description DESC
gh label delete NAME
gh label clone owner/source-repo

# Read colors programmatically
gh label list --json name,color | jq '.[] | select(.name=="bug")'
gh label list --json name,color | jq -r '.[] | "\(.name): #\(.color)"'
gh label list --json name,color | jq '.[] | select(.color=="ff0000")'
```

### GitHub API
```bash
# Create
curl -X POST -H "Authorization: token $TOKEN" \
  https://api.github.com/repos/OWNER/REPO/labels \
  -d '{"name":"bug","color":"f29513","description":"Something isn't working"}'

# Update (rename/recolor)
curl -X PATCH -H "Authorization: token $TOKEN" \
  https://api.github.com/repos/OWNER/REPO/labels/bug \
  -d '{"new_name":"critical-bug","color":"FF0000"}'

# Read
curl -H "Authorization: token $TOKEN" \
  https://api.github.com/repos/OWNER/REPO/labels[/LABEL_NAME]
```

## Projects v2 Field Options

### GraphQL via `gh`
```bash
# Read field options with colors
gh api graphql -f query='
  query($projectId: ID!) {
    node(id: $projectId) {
      ... on ProjectV2 {
        fields(first: 20) {
          nodes {
            ... on ProjectV2SingleSelectField {
              id name
              options { id name color }
            }
          }
        }
      }
    }
  }' -f projectId="PROJECT_NODE_ID"

# Get project ID
gh project list --owner OWNER
```

## Key Points
- Colors: 6-char hex without `#` prefix
- Repository labels: Simple CRUD via `gh label`
- Project fields: GraphQL required
- Export all: `gh label list --json name,color,description > labels.json`
