# GitHub Projects - Custom Fields Management

## Understanding Custom Fields

GitHub Projects v2 separates issue data from project metadata. Custom fields exist only in the project context and enable:

- **Status tracking** (Todo, In Progress, Done)
- **Priority levels** (High, Medium, Low)  
- **Sprint assignment** (Sprint 1, Sprint 2)
- **Story points** (Numeric estimates)
- **Due dates** (Timeline tracking)

## Field Discovery

```bash
# List all fields in project
gh project field-list 1 --owner "@me"

# Get field details as JSON
gh project field-list 1 --owner "@me" --format json

# Extract field IDs and types
gh project field-list 1 --owner "@me" --format json | jq '.fields[] | {id, name, dataType}'

# Find specific field ID by name
gh project field-list 1 --owner "@me" --format json | jq -r '.fields[] | select(.name=="Status") | .id'

# Get single-select options
gh project field-list 1 --owner "@me" --format json | jq '.fields[] | select(.name=="Status") | .options[]'
```

## Creating Custom Fields

```bash
# Text field (Priority, Notes)
gh project field-create 1 --owner "@me" --name "Priority" --data-type "text"

# Single select (Status dropdown)
gh project field-create 1 --owner "@me" --name "Status" --data-type "single_select" \
  --single-select-option "Todo" \
  --single-select-option "In Progress" \
  --single-select-option "In Review" \
  --single-select-option "Done"

# Number field (Story Points)
gh project field-create 1 --owner "@me" --name "Story Points" --data-type "number"

# Date field (Due Date)
gh project field-create 1 --owner "@me" --name "Due Date" --data-type "date"
```

## Updating Field Values

### Get Required IDs First
```bash
#!/bin/bash
PROJECT_NUM="1"
OWNER="@me"

# Get all necessary IDs
PROJECT_ID=$(gh project view $PROJECT_NUM --owner $OWNER --format json | jq -r '.id')
FIELD_ID=$(gh project field-list $PROJECT_NUM --owner $OWNER --format json | jq -r '.fields[] | select(.name=="Status") | .id')
OPTION_ID=$(gh project field-list $PROJECT_NUM --owner $OWNER --format json | jq -r '.fields[] | select(.name=="Status") | .options[] | select(.name=="In Progress") | .id')
ITEM_ID=$(gh project item-list $PROJECT_NUM --owner $OWNER --format json | jq -r '.items[0].id')

echo "Project ID: $PROJECT_ID"
echo "Field ID: $FIELD_ID" 
echo "Option ID: $OPTION_ID"
echo "Item ID: $ITEM_ID"
```

### Update Different Field Types
```bash
# Update single-select field (Status)
gh project item-edit --id $ITEM_ID --field-id $FIELD_ID --project-id $PROJECT_ID --single-select-option-id $OPTION_ID

# Update text field (Priority)
gh project item-edit --id $ITEM_ID --field-id $PRIORITY_FIELD_ID --project-id $PROJECT_ID --text "High"

# Update number field (Story Points)
gh project item-edit --id $ITEM_ID --field-id $POINTS_FIELD_ID --project-id $PROJECT_ID --number 5

# Update date field (Due Date)
gh project item-edit --id $ITEM_ID --field-id $DATE_FIELD_ID --project-id $PROJECT_ID --date "2024-12-31"

# Clear field value
gh project item-edit --id $ITEM_ID --field-id $FIELD_ID --project-id $PROJECT_ID --clear
```

## Common Field Management Patterns

### Status Workflow Automation
```bash
#!/bin/bash
# Move all assigned items to "In Progress"

PROJECT_NUM="1"
OWNER="@me"
CURRENT_USER=$(gh api user --jq .login)

# Get IDs
PROJECT_ID=$(gh project view $PROJECT_NUM --owner $OWNER --format json | jq -r '.id')
STATUS_FIELD_ID=$(gh project field-list $PROJECT_NUM --owner $OWNER --format json | jq -r '.fields[] | select(.name=="Status") | .id')
IN_PROGRESS_ID=$(gh project field-list $PROJECT_NUM --owner $OWNER --format json | jq -r '.fields[] | select(.name=="Status") | .options[] | select(.name=="In Progress") | .id')

# Update items assigned to current user
gh project item-list $PROJECT_NUM --owner $OWNER --format json | \
jq -r --arg user "$CURRENT_USER" '.items[] | select(.content.assignees[]?.login==$user) | .id' | \
while read item_id; do
    gh project item-edit --id "$item_id" --project-id "$PROJECT_ID" --field-id "$STATUS_FIELD_ID" --single-select-option-id "$IN_PROGRESS_ID"
    echo "Updated item $item_id to In Progress"
done
```

### Bulk Priority Assignment
```bash
#!/bin/bash
# Set priority based on issue labels

PROJECT_NUM="1" 
OWNER="@me"

PROJECT_ID=$(gh project view $PROJECT_NUM --owner $OWNER --format json | jq -r '.id')
PRIORITY_FIELD_ID=$(gh project field-list $PROJECT_NUM --owner $OWNER --format json | jq -r '.fields[] | select(.name=="Priority") | .id')

gh project item-list $PROJECT_NUM --owner $OWNER --format json | jq -r '.items[] | select(.content.labels) | {id, labels: [.content.labels[].name]}' | \
while IFS= read -r line; do
    item_id=$(echo "$line" | jq -r '.id')
    labels=$(echo "$line" | jq -r '.labels[]')
    
    priority=""
    if echo "$labels" | grep -q "urgent\|critical"; then
        priority="High"
    elif echo "$labels" | grep -q "important"; then
        priority="Medium" 
    else
        priority="Low"
    fi
    
    gh project item-edit --id "$item_id" --project-id "$PROJECT_ID" --field-id "$PRIORITY_FIELD_ID" --text "$priority"
    echo "Set priority $priority for item $item_id"
done
```

### Sprint Planning Helper
```bash
#!/bin/bash
# Assign story points based on issue complexity

PROJECT_NUM="1"
OWNER="@me"

PROJECT_ID=$(gh project view $PROJECT_NUM --owner $OWNER --format json | jq -r '.id')
POINTS_FIELD_ID=$(gh project field-list $PROJECT_NUM --owner $OWNER --format json | jq -r '.fields[] | select(.name=="Story Points") | .id')

# Auto-assign points based on labels
gh project item-list $PROJECT_NUM --owner $OWNER --format json | jq -r '.items[] | select(.content.labels) | {id, labels: [.content.labels[].name]}' | \
while IFS= read -r line; do
    item_id=$(echo "$line" | jq -r '.id')
    labels=$(echo "$line" | jq -r '.labels[]')
    
    points=1  # default
    if echo "$labels" | grep -q "epic\|large"; then
        points=8
    elif echo "$labels" | grep -q "feature\|enhancement"; then
        points=3
    elif echo "$labels" | grep -q "bug"; then
        points=2
    fi
    
    gh project item-edit --id "$item_id" --project-id "$PROJECT_ID" --field-id "$POINTS_FIELD_ID" --number $points
    echo "Assigned $points points to item $item_id"
done
```

## Field Value Extraction

```bash
#!/bin/bash
# Generate field value reports

PROJECT_NUM="1"
OWNER="@me"

echo "=== Project Field Summary ==="

# Get items with field values
gh project item-list $PROJECT_NUM --owner $OWNER --format json | jq -r '
.items[] | 
{
  title: .content.title,
  url: .content.url,
  status: (.fieldValues[] | select(.field.name=="Status") | .name // "No Status"),
  priority: (.fieldValues[] | select(.field.name=="Priority") | .text // "No Priority"),
  points: (.fieldValues[] | select(.field.name=="Story Points") | .number // 0)
} | 
"\(.title) | \(.status) | \(.priority) | \(.points) points"'

echo
echo "=== Status Distribution ==="

# Count items by status
gh project item-list $PROJECT_NUM --owner $OWNER --format json | jq -r '
.items | 
group_by(.fieldValues[] | select(.field.name=="Status") | .name // "No Status") | 
map("\(.[0].fieldValues[] | select(.field.name=="Status") | .name // "No Status"): \(length)") | 
.[]'
```

## Key Takeaways

- **Custom fields are project-specific** - not part of the issue itself
- **Field IDs are required** for all update operations  
- **Option IDs are needed** for single-select field updates
- **Automation requires ID resolution** before field updates
- **Batch operations** are more efficient than individual updates