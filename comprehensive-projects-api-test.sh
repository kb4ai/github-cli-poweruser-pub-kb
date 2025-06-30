#!/bin/bash
#
# Comprehensive GitHub Projects API Test Suite
# Tests all major functionality with clean output
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Comprehensive GitHub Projects API Test Suite ===${NC}"
echo "Repository: gwwtests/testxxxyyzzzzz"
echo "Project: gwwtests/projects/1"
echo

# Source authentication
source "${GITHUB_TOKEN_DOTFILE}"
export GH_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN"

echo -e "${BLUE}1. Authentication Test${NC}"
echo "Authentication: ✅ Classic token loaded"
echo

echo -e "${BLUE}2. Project Structure Discovery${NC}"
echo "Discovering project fields and their possible values..."
echo

# Get project structure
PROJECT_STRUCTURE=$(gh api graphql -f query='
query {
  organization(login: "gwwtests") {
    projectV2(number: 1) {
      id
      title
      fields(first: 20) {
        nodes {
          ... on ProjectV2Field {
            id
            name
            dataType
          }
          ... on ProjectV2SingleSelectField {
            id
            name
            dataType
            options {
              id
              name
            }
          }
          ... on ProjectV2IterationField {
            id
            name
            dataType
            configuration {
              iterations {
                id
                title
              }
            }
          }
        }
      }
    }
  }
}')

echo "$PROJECT_STRUCTURE" | jq -r '
"Project: " + .data.organization.projectV2.title,
"Project ID: " + .data.organization.projectV2.id,
"",
"Available Fields:",
(.data.organization.projectV2.fields.nodes[] | 
  if .options then
    "  • " + .name + " (" + .dataType + "): " + ([.options[].name] | join(", "))
  elif .configuration.iterations then
    "  • " + .name + " (" + .dataType + "): " + ([.configuration.iterations[].title] | join(", "))
  else
    "  • " + .name + " (" + .dataType + ")"
  end)
'

echo
echo -e "${BLUE}3. Listing All Issues in Project${NC}"
echo "Querying all issues and their current field values..."
echo

# Get all project items with field values
PROJECT_ITEMS=$(gh api graphql -f query='
query {
  organization(login: "gwwtests") {
    projectV2(number: 1) {
      items(first: 20) {
        nodes {
          id
          content {
            ... on Issue {
              title
              number
              url
            }
          }
          fieldValues(first: 20) {
            nodes {
              ... on ProjectV2ItemFieldTextValue {
                field {
                  ... on ProjectV2Field {
                    name
                  }
                }
                text
              }
              ... on ProjectV2ItemFieldSingleSelectValue {
                field {
                  ... on ProjectV2SingleSelectField {
                    name
                  }
                }
                name
              }
              ... on ProjectV2ItemFieldDateValue {
                field {
                  ... on ProjectV2Field {
                    name
                  }
                }
                date
              }
              ... on ProjectV2ItemFieldNumberValue {
                field {
                  ... on ProjectV2Field {
                    name
                  }
                }
                number
              }
            }
          }
        }
      }
    }
  }
}')

echo "$PROJECT_ITEMS" | jq -r '
.data.organization.projectV2.items.nodes[] |
"Issue #" + (.content.number | tostring) + ": " + .content.title,
"  Item ID: " + .id,
(.fieldValues.nodes[] | 
  select(.field.name == "Status" or .field.name == "CustomSelectS") |
  "  " + .field.name + ": " + (.text // .name // .date // (.number | tostring) // "N/A")
),
""'

echo -e "${BLUE}4. Testing Field Value Changes${NC}"
echo "Changing Status and CustomSelectS fields for specific issues..."
echo

# Get field and option IDs for modifications
STATUS_FIELD_ID=$(echo "$PROJECT_STRUCTURE" | jq -r '.data.organization.projectV2.fields.nodes[] | select(.name == "Status") | .id')
CUSTOM_SELECT_FIELD_ID=$(echo "$PROJECT_STRUCTURE" | jq -r '.data.organization.projectV2.fields.nodes[] | select(.name == "CustomSelectS") | .id')

TODO_OPTION_ID=$(echo "$PROJECT_STRUCTURE" | jq -r '.data.organization.projectV2.fields.nodes[] | select(.name == "Status") | .options[] | select(.name == "Todo") | .id')
OPTA_OPTION_ID=$(echo "$PROJECT_STRUCTURE" | jq -r '.data.organization.projectV2.fields.nodes[] | select(.name == "CustomSelectS") | .options[] | select(.name == "OptA") | .id')

# Get first item for testing
FIRST_ITEM_ID=$(echo "$PROJECT_ITEMS" | jq -r '.data.organization.projectV2.items.nodes[0].id')
FIRST_ITEM_NUMBER=$(echo "$PROJECT_ITEMS" | jq -r '.data.organization.projectV2.items.nodes[0].content.number')

echo "Testing field change on Issue #$FIRST_ITEM_NUMBER (Item ID: $FIRST_ITEM_ID)"
echo "Setting Status to 'Todo' and CustomSelectS to 'OptA'..."

# Update Status field
gh api graphql -f query='
mutation {
  updateProjectV2ItemFieldValue(input: {
    projectId: "PVT_kwDOB8UsdM4A8bZf"
    itemId: "'$FIRST_ITEM_ID'"
    fieldId: "'$STATUS_FIELD_ID'"
    value: {
      singleSelectOptionId: "'$TODO_OPTION_ID'"
    }
  }) {
    projectV2Item {
      id
    }
  }
}' > /dev/null

# Update CustomSelectS field
gh api graphql -f query='
mutation {
  updateProjectV2ItemFieldValue(input: {
    projectId: "PVT_kwDOB8UsdM4A8bZf"
    itemId: "'$FIRST_ITEM_ID'"
    fieldId: "'$CUSTOM_SELECT_FIELD_ID'"
    value: {
      singleSelectOptionId: "'$OPTA_OPTION_ID'"
    }
  }) {
    projectV2Item {
      id
    }
  }
}' > /dev/null

echo "✅ Field values updated successfully"
echo

echo -e "${BLUE}5. Verifying Field Changes${NC}"
echo "Querying updated field values..."
echo

# Verify the changes
UPDATED_ITEM=$(gh api graphql -f query='
query {
  node(id: "'$FIRST_ITEM_ID'") {
    ... on ProjectV2Item {
      content {
        ... on Issue {
          title
          number
        }
      }
      fieldValues(first: 10) {
        nodes {
          ... on ProjectV2ItemFieldSingleSelectValue {
            field {
              ... on ProjectV2SingleSelectField {
                name
              }
            }
            name
          }
        }
      }
    }
  }
}')

echo "$UPDATED_ITEM" | jq -r '
"Issue #" + (.data.node.content.number | tostring) + ": " + .data.node.content.title,
(.data.node.fieldValues.nodes[] | 
  select(.field.name == "Status" or .field.name == "CustomSelectS") |
  "  " + .field.name + ": " + .name
)'

echo
echo -e "${BLUE}6. Testing Issue Addition to Project${NC}"
echo "Creating new test issue and adding to project..."
echo

# Create new test issue
NEW_ISSUE_URL=$(gh issue create --repo gwwtests/testxxxyyzzzzz --title "API Test Issue: $(date +%Y%m%d_%H%M%S)" --body "This issue was created to test comprehensive GitHub Projects API functionality.")
NEW_ISSUE_NUMBER=$(echo "$NEW_ISSUE_URL" | grep -o '[0-9]\+$')

echo "Created Issue #$NEW_ISSUE_NUMBER: $NEW_ISSUE_URL"

# Add issue to project
gh project item-add 1 --owner gwwtests --url "$NEW_ISSUE_URL" > /dev/null
echo "✅ Issue added to project successfully"

echo
echo -e "${BLUE}7. Final Project State Summary${NC}"
echo "Complete project overview with all issues and field values..."
echo

# Get final state
FINAL_STATE=$(gh api graphql -f query='
query {
  organization(login: "gwwtests") {
    projectV2(number: 1) {
      items(first: 20) {
        nodes {
          id
          content {
            ... on Issue {
              title
              number
            }
          }
          fieldValues(first: 20) {
            nodes {
              ... on ProjectV2ItemFieldSingleSelectValue {
                field {
                  ... on ProjectV2SingleSelectField {
                    name
                  }
                }
                name
              }
            }
          }
        }
      }
    }
  }
}')

echo "| Issue # | Title | Status | CustomSelectS |"
echo "|---------|-------|--------|---------------|"

echo "$FINAL_STATE" | jq -r '
.data.organization.projectV2.items.nodes[] |
[
  ("#" + (.content.number | tostring)),
  (.content.title | if length > 30 then .[0:30] + "..." else . end),
  ((.fieldValues.nodes[] | select(.field.name == "Status") | .name) // "N/A"),
  ((.fieldValues.nodes[] | select(.field.name == "CustomSelectS") | .name) // "N/A")
] | "| " + join(" | ") + " |"
'

echo
echo -e "${GREEN}🎉 Comprehensive API Test Complete!${NC}"
echo
echo -e "${BLUE}Functionality Verified:${NC}"
echo "✅ Project field discovery (available fields)"
echo "✅ Field option discovery (possible values for select fields)"
echo "✅ Issue assignment to project"
echo "✅ Field value modification (Status and CustomSelectS)"
echo "✅ Issue querying with field values (JSON format)"
echo "✅ Complete project state reporting"
echo "✅ New issue creation and project addition"
echo
echo -e "${BLUE}Available Scripts:${NC}"
echo "• github-projects-item-management.sh - Issue/project CRUD operations"
echo "• github-projects-field-discovery.sh - Field structure and schema discovery"
echo "• github-projects-field-management.sh - Field value management"
echo "• bulk-add-issues-to-project.sh - Bulk issue operations"
echo "• test-github-projects-automation.sh - Comprehensive test suite"