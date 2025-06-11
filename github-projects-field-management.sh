#!/bin/bash
#
# GitHub Projects Field Management - Field Value CRUD Operations
# 
# This script provides comprehensive field value management for GitHub Projects.
# It supports reading, setting, and bulk updating field values for project items.
#
# Usage Examples:
#   ./github-projects-field-management.sh get-field-value 1 gwwtests PVTI_lADOA1ZjX84AWImYzgJla5U "Status"
#   ./github-projects-field-management.sh set-field-by-name 1 gwwtests PVTI_lADOA1ZjX84AWImYzgJla5U "Status" "Done"
#   ./github-projects-field-management.sh set-field-by-id 1 gwwtests PVTI_lADOA1ZjX84AWImYzgJla5U FIELD_ID OPTION_ID
#   ./github-projects-field-management.sh bulk-update 1 gwwtests updates.csv
#
# Requirements:
# - GitHub CLI (gh) with authentication
# - project scope (write access)
# - jq for JSON processing
#

set -e

# Script configuration
VERSION="1.0.0"
SCRIPT_NAME="github-projects-field-management"
LOG_FILE="/tmp/${SCRIPT_NAME}.log"
MAX_RETRIES=3
RETRY_DELAY=2

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    log "ERROR: $1"
    exit 1
}

# Success message
success() {
    echo -e "${GREEN}✓ $1${NC}"
    log "SUCCESS: $1"
}

# Warning message
warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    log "WARNING: $1"
}

# Info message
info() {
    echo -e "${BLUE}ℹ $1${NC}"
    log "INFO: $1"
}

# Retry function with exponential backoff
retry_command() {
    local max_attempts=$MAX_RETRIES
    local delay=$RETRY_DELAY
    local attempt=1
    local cmd="$*"
    
    while [ $attempt -le $max_attempts ]; do
        log "Attempting: $cmd (attempt $attempt/$max_attempts)"
        
        if eval "$cmd"; then
            return 0
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            log "FAILED: $cmd after $max_attempts attempts"
            return 1
        fi
        
        log "RETRY: $cmd failed, waiting $delay seconds..."
        sleep $delay
        delay=$((delay * 2))
        attempt=$((attempt + 1))
    done
}

# Validate GitHub CLI authentication and scopes
validate_auth() {
    if ! gh auth status >/dev/null 2>&1; then
        error_exit "GitHub CLI not authenticated. Please run: gh auth login --scopes project"
    fi
    
    # Check for project scope (write access needed)
    if ! gh auth status 2>&1 | grep -q "project"; then
        warning "Project scope (write access) may not be available."
        info "Consider running: gh auth refresh -s project --hostname github.com"
        info "You may need to manually authorize project access at: https://github.com/settings/tokens"
    fi
}

# Get project ID from project number and owner
get_project_id() {
    local project_num="$1"
    local owner="$2"
    
    local project_id
    if [[ "$owner" == *"/"* ]]; then
        # User project
        local username=$(echo "$owner" | cut -d'/' -f1)
        project_id=$(retry_command "gh api graphql -f query='query{ user(login: \"$username\"){ projectV2(number: $project_num) { id } } }'" | jq -r '.data.user.projectV2.id')
    else
        # Organization project
        project_id=$(retry_command "gh api graphql -f query='query{ organization(login: \"$owner\"){ projectV2(number: $project_num) { id } } }'" | jq -r '.data.organization.projectV2.id')
    fi
    
    if [ -z "$project_id" ] || [ "$project_id" = "null" ]; then
        error_exit "Could not find project $project_num for owner $owner"
    fi
    
    echo "$project_id"
}

# Get field information by name
get_field_info() {
    local project_num="$1"
    local owner="$2"
    local field_name="$3"
    
    # Get project ID
    local project_id
    project_id=$(get_project_id "$project_num" "$owner")
    
    # Query field information
    local query='query($projectId: ID!) {
        node(id: $projectId) {
            ... on ProjectV2 {
                fields(first: 50) {
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
                                completedIterations {
                                    id
                                    title
                                }
                            }
                        }
                    }
                }
            }
        }
    }'
    
    local result
    result=$(retry_command "gh api graphql -f query='$query' -F projectId='$project_id'")
    
    local field_data
    field_data=$(echo "$result" | jq --arg name "$field_name" '.data.node.fields.nodes[] | select(.name == $name)')
    
    if [ -z "$field_data" ] || [ "$field_data" = "null" ]; then
        error_exit "Field '$field_name' not found in project"
    fi
    
    echo "$field_data"
}

# Get current field values for an item
get_item_field_values() {
    local project_num="$1"
    local owner="$2"
    local item_id="$3"
    local field_name="${4:-}"
    
    info "Getting field values for item $item_id"
    
    # Get project ID
    local project_id
    project_id=$(get_project_id "$project_num" "$owner")
    
    # Query item field values
    local query='query($itemId: ID!) {
        node(id: $itemId) {
            ... on ProjectV2Item {
                id
                content {
                    ... on Issue {
                        title
                        number
                        url
                    }
                    ... on PullRequest {
                        title
                        number
                        url
                    }
                    ... on DraftIssue {
                        title
                    }
                }
                fieldValues(first: 50) {
                    nodes {
                        ... on ProjectV2ItemFieldTextValue {
                            field {
                                ... on ProjectV2Field {
                                    id
                                    name
                                }
                            }
                            text
                        }
                        ... on ProjectV2ItemFieldNumberValue {
                            field {
                                ... on ProjectV2Field {
                                    id
                                    name
                                }
                            }
                            number
                        }
                        ... on ProjectV2ItemFieldDateValue {
                            field {
                                ... on ProjectV2Field {
                                    id
                                    name
                                }
                            }
                            date
                        }
                        ... on ProjectV2ItemFieldSingleSelectValue {
                            field {
                                ... on ProjectV2SingleSelectField {
                                    id
                                    name
                                }
                            }
                            optionId
                            name
                        }
                        ... on ProjectV2ItemFieldIterationValue {
                            field {
                                ... on ProjectV2IterationField {
                                    id
                                    name
                                }
                            }
                            iterationId
                            title
                            startDate
                            duration
                        }
                    }
                }
            }
        }
    }'
    
    local result
    result=$(retry_command "gh api graphql -f query='$query' -F itemId='$item_id'")
    
    # Check if item exists
    local item_title
    item_title=$(echo "$result" | jq -r '.data.node.content.title // .data.node.content.title // "Unknown Item"')
    
    if [ "$item_title" = "null" ]; then
        error_exit "Item $item_id not found or not accessible"
    fi
    
    echo -e "\n${BLUE}=== Field Values for: $item_title ===${NC}"
    echo -e "${GREEN}Item ID:${NC} $item_id"
    echo
    
    # If specific field requested
    if [ -n "$field_name" ]; then
        local field_value
        field_value=$(echo "$result" | jq --arg name "$field_name" '.data.node.fieldValues.nodes[] | select(.field.name == $name)')
        
        if [ -z "$field_value" ] || [ "$field_value" = "null" ]; then
            warning "Field '$field_name' has no value set for this item"
            return
        fi
        
        local value_type
        value_type=$(echo "$field_value" | jq -r 'if .text then "text" elif .number then "number" elif .date then "date" elif .name then "single_select" elif .title then "iteration" else "unknown" end')
        
        echo -e "${GREEN}Field:${NC} $field_name"
        case "$value_type" in
            "text")
                echo -e "${GREEN}Value:${NC} $(echo "$field_value" | jq -r '.text')"
                ;;
            "number")
                echo -e "${GREEN}Value:${NC} $(echo "$field_value" | jq -r '.number')"
                ;;
            "date")
                echo -e "${GREEN}Value:${NC} $(echo "$field_value" | jq -r '.date')"
                ;;
            "single_select")
                echo -e "${GREEN}Value:${NC} $(echo "$field_value" | jq -r '.name')"
                echo -e "${GREEN}Option ID:${NC} $(echo "$field_value" | jq -r '.optionId')"
                ;;
            "iteration")
                echo -e "${GREEN}Value:${NC} $(echo "$field_value" | jq -r '.title')"
                echo -e "${GREEN}Iteration ID:${NC} $(echo "$field_value" | jq -r '.iterationId')"
                echo -e "${GREEN}Start Date:${NC} $(echo "$field_value" | jq -r '.startDate')"
                ;;
            *)
                echo -e "${GREEN}Value:${NC} $(echo "$field_value" | jq -r '.')"
                ;;
        esac
        
        success "Retrieved field value"
        return
    fi
    
    # Show all field values
    printf "%-20s %-15s %s\n" "FIELD NAME" "TYPE" "VALUE"
    printf "%-20s %-15s %s\n" "$(printf '%.20s' "--------------------")" "$(printf '%.15s' "---------------")" "$(printf '%.30s' "------------------------------")"
    
    echo "$result" | jq -r '
    .data.node.fieldValues.nodes[] |
    [
        .field.name,
        (if .text then "TEXT" 
         elif .number then "NUMBER" 
         elif .date then "DATE" 
         elif .name then "SINGLE_SELECT" 
         elif .title then "ITERATION" 
         else "UNKNOWN" end),
        (.text // .number // .date // .name // .title // "N/A")
    ] | @tsv' | \
    while IFS=$'\t' read -r field_name field_type value; do
        printf "%-20s %-15s %s\n" "$field_name" "$field_type" "$value"
    done
    
    echo
    success "Retrieved all field values"
}

# Set field value by field name and option name
set_field_by_name() {
    local project_num="$1"
    local owner="$2"
    local item_id="$3"
    local field_name="$4"
    local value="$5"
    local dry_run="${6:-false}"
    
    info "Setting field '$field_name' to '$value' for item $item_id"
    
    if [ "$dry_run" = "true" ]; then
        info "DRY RUN MODE: Would set field '$field_name' to '$value'"
        return 0
    fi
    
    # Get project ID
    local project_id
    project_id=$(get_project_id "$project_num" "$owner")
    
    # Get field information
    local field_data
    field_data=$(get_field_info "$project_num" "$owner" "$field_name")
    
    local field_id
    local data_type
    field_id=$(echo "$field_data" | jq -r '.id')
    data_type=$(echo "$field_data" | jq -r '.dataType')
    
    info "Field ID: $field_id, Data Type: $data_type"
    
    # Build mutation based on field type
    local mutation
    local variables
    
    case "$data_type" in
        "TEXT")
            mutation='mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $value: String!) {
                updateProjectV2ItemFieldValue(input: {
                    projectId: $projectId
                    itemId: $itemId
                    fieldId: $fieldId
                    value: { text: $value }
                }) {
                    projectV2Item {
                        id
                    }
                }
            }'
            variables="-F projectId='$project_id' -F itemId='$item_id' -F fieldId='$field_id' -F value='$value'"
            ;;
        "NUMBER")
            # Validate number
            if ! [[ "$value" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
                error_exit "Invalid number format: $value"
            fi
            
            mutation='mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $value: Float!) {
                updateProjectV2ItemFieldValue(input: {
                    projectId: $projectId
                    itemId: $itemId
                    fieldId: $fieldId
                    value: { number: $value }
                }) {
                    projectV2Item {
                        id
                    }
                }
            }'
            variables="-F projectId='$project_id' -F itemId='$item_id' -F fieldId='$field_id' -F value='$value'"
            ;;
        "DATE")
            # Validate date format (YYYY-MM-DD)
            if ! [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
                error_exit "Invalid date format: $value (expected YYYY-MM-DD)"
            fi
            
            mutation='mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $value: Date!) {
                updateProjectV2ItemFieldValue(input: {
                    projectId: $projectId
                    itemId: $itemId
                    fieldId: $fieldId
                    value: { date: $value }
                }) {
                    projectV2Item {
                        id
                    }
                }
            }'
            variables="-F projectId='$project_id' -F itemId='$item_id' -F fieldId='$field_id' -F value='$value'"
            ;;
        "SINGLE_SELECT")
            # Find option ID by name
            local option_id
            option_id=$(echo "$field_data" | jq -r --arg name "$value" '.options[] | select(.name == $name) | .id')
            
            if [ -z "$option_id" ] || [ "$option_id" = "null" ]; then
                error_exit "Option '$value' not found in field '$field_name'"
            fi
            
            info "Option ID: $option_id"
            
            mutation='mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
                updateProjectV2ItemFieldValue(input: {
                    projectId: $projectId
                    itemId: $itemId
                    fieldId: $fieldId
                    value: { singleSelectOptionId: $optionId }
                }) {
                    projectV2Item {
                        id
                    }
                }
            }'
            variables="-F projectId='$project_id' -F itemId='$item_id' -F fieldId='$field_id' -F optionId='$option_id'"
            ;;
        "ITERATION")
            # Find iteration ID by title
            local iteration_id
            iteration_id=$(echo "$field_data" | jq -r --arg title "$value" '.configuration.iterations[] | select(.title == $title) | .id')
            
            if [ -z "$iteration_id" ] || [ "$iteration_id" = "null" ]; then
                # Check completed iterations
                iteration_id=$(echo "$field_data" | jq -r --arg title "$value" '.configuration.completedIterations[] | select(.title == $title) | .id')
                
                if [ -z "$iteration_id" ] || [ "$iteration_id" = "null" ]; then
                    error_exit "Iteration '$value' not found in field '$field_name'"
                fi
            fi
            
            info "Iteration ID: $iteration_id"
            
            mutation='mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $iterationId: String!) {
                updateProjectV2ItemFieldValue(input: {
                    projectId: $projectId
                    itemId: $itemId
                    fieldId: $fieldId
                    value: { iterationId: $iterationId }
                }) {
                    projectV2Item {
                        id
                    }
                }
            }'
            variables="-F projectId='$project_id' -F itemId='$item_id' -F fieldId='$field_id' -F iterationId='$iteration_id'"
            ;;
        *)
            error_exit "Unsupported field type: $data_type"
            ;;
    esac
    
    # Execute mutation
    local result
    result=$(retry_command "gh api graphql -f query='$mutation' $variables")
    
    # Check for errors
    local errors
    errors=$(echo "$result" | jq -r '.errors[]?.message // empty')
    
    if [ -n "$errors" ]; then
        error_exit "Failed to update field: $errors"
    fi
    
    local updated_item_id
    updated_item_id=$(echo "$result" | jq -r '.data.updateProjectV2ItemFieldValue.projectV2Item.id')
    
    if [ -z "$updated_item_id" ] || [ "$updated_item_id" = "null" ]; then
        error_exit "Failed to update field (no item ID returned)"
    fi
    
    success "Updated field '$field_name' to '$value' for item $item_id"
}

# Set field value by field ID and option ID (for advanced usage)
set_field_by_id() {
    local project_num="$1"
    local owner="$2"
    local item_id="$3"
    local field_id="$4"
    local option_id="$5"
    local dry_run="${6:-false}"
    
    info "Setting field $field_id to option $option_id for item $item_id"
    
    if [ "$dry_run" = "true" ]; then
        info "DRY RUN MODE: Would set field $field_id to option $option_id"
        return 0
    fi
    
    # Get project ID
    local project_id
    project_id=$(get_project_id "$project_num" "$owner")
    
    # Use mutation for single select (most common use case for ID-based updates)
    local mutation='mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
        updateProjectV2ItemFieldValue(input: {
            projectId: $projectId
            itemId: $itemId
            fieldId: $fieldId
            value: { singleSelectOptionId: $optionId }
        }) {
            projectV2Item {
                id
            }
        }
    }'
    
    # Execute mutation
    local result
    result=$(retry_command "gh api graphql -f query='$mutation' -F projectId='$project_id' -F itemId='$item_id' -F fieldId='$field_id' -F optionId='$option_id'")
    
    # Check for errors
    local errors
    errors=$(echo "$result" | jq -r '.errors[]?.message // empty')
    
    if [ -n "$errors" ]; then
        error_exit "Failed to update field: $errors"
    fi
    
    local updated_item_id
    updated_item_id=$(echo "$result" | jq -r '.data.updateProjectV2ItemFieldValue.projectV2Item.id')
    
    if [ -z "$updated_item_id" ] || [ "$updated_item_id" = "null" ]; then
        error_exit "Failed to update field (no item ID returned)"
    fi
    
    success "Updated field $field_id to option $option_id for item $item_id"
}

# Clear field value
clear_field_value() {
    local project_num="$1"
    local owner="$2"
    local item_id="$3"
    local field_name="$4"
    local dry_run="${5:-false}"
    
    info "Clearing field '$field_name' for item $item_id"
    
    if [ "$dry_run" = "true" ]; then
        info "DRY RUN MODE: Would clear field '$field_name'"
        return 0
    fi
    
    # Get project ID
    local project_id
    project_id=$(get_project_id "$project_num" "$owner")
    
    # Get field information
    local field_data
    field_data=$(get_field_info "$project_num" "$owner" "$field_name")
    
    local field_id
    field_id=$(echo "$field_data" | jq -r '.id')
    
    # Clear field mutation
    local mutation='mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!) {
        clearProjectV2ItemFieldValue(input: {
            projectId: $projectId
            itemId: $itemId
            fieldId: $fieldId
        }) {
            projectV2Item {
                id
            }
        }
    }'
    
    # Execute mutation
    local result
    result=$(retry_command "gh api graphql -f query='$mutation' -F projectId='$project_id' -F itemId='$item_id' -F fieldId='$field_id'")
    
    # Check for errors
    local errors
    errors=$(echo "$result" | jq -r '.errors[]?.message // empty')
    
    if [ -n "$errors" ]; then
        error_exit "Failed to clear field: $errors"
    fi
    
    local updated_item_id
    updated_item_id=$(echo "$result" | jq -r '.data.clearProjectV2ItemFieldValue.projectV2Item.id')
    
    if [ -z "$updated_item_id" ] || [ "$updated_item_id" = "null" ]; then
        error_exit "Failed to clear field (no item ID returned)"
    fi
    
    success "Cleared field '$field_name' for item $item_id"
}

# Bulk update field values from CSV file
bulk_update_fields() {
    local project_num="$1"
    local owner="$2"
    local file="$3"
    local dry_run="${4:-false}"
    
    if [ ! -f "$file" ]; then
        error_exit "File not found: $file"
    fi
    
    info "Bulk updating field values from $file"
    
    if [ "$dry_run" = "true" ]; then
        info "DRY RUN MODE: Processing file without making changes"
    fi
    
    local updated=0
    local failed=0
    local line_num=0
    
    # Expected CSV format: item_id,field_name,value
    while IFS=',' read -r item_id field_name value || [ -n "$item_id" ]; do
        line_num=$((line_num + 1))
        
        # Skip empty lines and header
        if [ -z "$item_id" ] || [ "$item_id" = "item_id" ] || [[ "$item_id" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Clean up values (remove quotes and whitespace)
        item_id=$(echo "$item_id" | sed 's/^[[:space:]]*"\?//' | sed 's/"\?[[:space:]]*$//')
        field_name=$(echo "$field_name" | sed 's/^[[:space:]]*"\?//' | sed 's/"\?[[:space:]]*$//')
        value=$(echo "$value" | sed 's/^[[:space:]]*"\?//' | sed 's/"\?[[:space:]]*$//')
        
        info "Line $line_num: Updating $item_id -> $field_name = $value"
        
        if set_field_by_name "$project_num" "$owner" "$item_id" "$field_name" "$value" "$dry_run" >/dev/null 2>&1; then
            updated=$((updated + 1))
            success "Line $line_num: Updated $item_id"
        else
            failed=$((failed + 1))
            warning "Line $line_num: Failed to update $item_id"
        fi
        
        # Rate limiting: small delay between requests
        if [ "$dry_run" != "true" ]; then
            sleep 0.5
        fi
    done < "$file"
    
    echo
    if [ "$dry_run" = "true" ]; then
        success "DRY RUN complete: $updated would be updated, $failed would fail"
    else
        success "Bulk update complete: $updated updated, $failed failed"
    fi
}

# Show usage information
show_usage() {
    cat << EOF
${BLUE}GitHub Projects Field Management v$VERSION${NC}

${GREEN}DESCRIPTION:${NC}
    Comprehensive field value management for GitHub Projects items.
    Supports reading, setting, clearing, and bulk updating field values.

${GREEN}USAGE:${NC}
    $0 <command> <project_number> <owner> [arguments...]

${GREEN}COMMANDS:${NC}
    ${YELLOW}get-field-value${NC} <project_num> <owner> <item_id> [field_name]
        Get field value(s) for a project item
        
    ${YELLOW}set-field-by-name${NC} <project_num> <owner> <item_id> <field_name> <value> [--dry-run]
        Set field value using field name and option/value name
        
    ${YELLOW}set-field-by-id${NC} <project_num> <owner> <item_id> <field_id> <option_id> [--dry-run]
        Set single-select field value using field ID and option ID
        
    ${YELLOW}clear-field-value${NC} <project_num> <owner> <item_id> <field_name> [--dry-run]
        Clear/remove field value for a project item
        
    ${YELLOW}bulk-update${NC} <project_num> <owner> <csv_file> [--dry-run]
        Bulk update field values from CSV file
        CSV format: item_id,field_name,value

${GREEN}EXAMPLES:${NC}
    # Get all field values for an item
    $0 get-field-value 1 gwwtests PVTI_lADOA1ZjX84AWImYzgJla5U
    
    # Get specific field value
    $0 get-field-value 1 gwwtests PVTI_lADOA1ZjX84AWImYzgJla5U "Status"
    
    # Set Status field to "Done"
    $0 set-field-by-name 1 gwwtests PVTI_lADOA1ZjX84AWImYzgJla5U "Status" "Done"
    
    # Set field using IDs (advanced)
    $0 set-field-by-id 1 gwwtests PVTI_lADOA1ZjX84AWImYzgJla5U FIELD_ID OPTION_ID
    
    # Clear a field value
    $0 clear-field-value 1 gwwtests PVTI_lADOA1ZjX84AWImYzgJla5U "Priority"
    
    # Dry run field update
    $0 set-field-by-name 1 gwwtests PVTI_lADOA1ZjX84AWImYzgJla5U "Status" "In Progress" --dry-run
    
    # Bulk update from CSV
    $0 bulk-update 1 gwwtests updates.csv
    
    # Dry run bulk update
    $0 bulk-update 1 gwwtests updates.csv --dry-run

${GREEN}SUPPORTED FIELD TYPES:${NC}
    - ${YELLOW}TEXT${NC}: Plain text values
    - ${YELLOW}NUMBER${NC}: Numeric values (integers or decimals)
    - ${YELLOW}DATE${NC}: Date values (YYYY-MM-DD format)
    - ${YELLOW}SINGLE_SELECT${NC}: Dropdown options (use option name)
    - ${YELLOW}ITERATION${NC}: Sprint/iteration values (use iteration title)

${GREEN}CSV BULK UPDATE FORMAT:${NC}
    CSV file should have header: item_id,field_name,value
    Example:
    ${YELLOW}item_id,field_name,value${NC}
    PVTI_lADOA1ZjX84AWImYzgJla5U,Status,Done
    PVTI_lADOA1ZjX84AWImYzgJla5V,Priority,High
    PVTI_lADOA1ZjX84AWImYzgJla5W,Story Points,5

${GREEN}OWNER FORMATS:${NC}
    - Organization: ${YELLOW}orgname${NC}
    - User: ${YELLOW}username${NC}
    - Current user: ${YELLOW}@me${NC}

${GREEN}DRY RUN MODE:${NC}
    Add ${YELLOW}--dry-run${NC} flag to preview changes without executing them.
    Useful for testing bulk operations or validating field updates.

${GREEN}REQUIREMENTS:${NC}
    - GitHub CLI (gh) installed and authenticated
    - Project scopes: project (write access required)
    - jq for JSON processing
    - Internet connection

${GREEN}FILES:${NC}
    Log file: $LOG_FILE
    
${GREEN}AUTHENTICATION:${NC}
    Run: gh auth refresh -s project --hostname github.com
    Or visit: https://github.com/settings/tokens

EOF
}

# Main function
main() {
    local command="$1"
    
    # Handle help and version
    case "$command" in
        -h|--help|help)
            show_usage
            exit 0
            ;;
        -v|--version|version)
            echo "$SCRIPT_NAME v$VERSION"
            exit 0
            ;;
    esac
    
    # Validate dependencies
    if ! command -v gh >/dev/null 2>&1; then
        error_exit "GitHub CLI (gh) is not installed. Please install from: https://cli.github.com/"
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        error_exit "jq is not installed. Please install jq for JSON processing."
    fi
    
    # Validate authentication
    validate_auth
    
    # Process commands
    case "$command" in
        get-field-value)
            if [ $# -lt 4 ]; then
                error_exit "Usage: $0 get-field-value <project_num> <owner> <item_id> [field_name]"
            fi
            get_item_field_values "$2" "$3" "$4" "$5"
            ;;
        set-field-by-name)
            if [ $# -lt 6 ]; then
                error_exit "Usage: $0 set-field-by-name <project_num> <owner> <item_id> <field_name> <value> [--dry-run]"
            fi
            local dry_run="false"
            if [ "$7" = "--dry-run" ]; then
                dry_run="true"
            fi
            set_field_by_name "$2" "$3" "$4" "$5" "$6" "$dry_run"
            ;;
        set-field-by-id)
            if [ $# -lt 6 ]; then
                error_exit "Usage: $0 set-field-by-id <project_num> <owner> <item_id> <field_id> <option_id> [--dry-run]"
            fi
            local dry_run="false"
            if [ "$7" = "--dry-run" ]; then
                dry_run="true"
            fi
            set_field_by_id "$2" "$3" "$4" "$5" "$6" "$dry_run"
            ;;
        clear-field-value)
            if [ $# -lt 5 ]; then
                error_exit "Usage: $0 clear-field-value <project_num> <owner> <item_id> <field_name> [--dry-run]"
            fi
            local dry_run="false"
            if [ "$6" = "--dry-run" ]; then
                dry_run="true"
            fi
            clear_field_value "$2" "$3" "$4" "$5" "$dry_run"
            ;;
        bulk-update)
            if [ $# -lt 4 ]; then
                error_exit "Usage: $0 bulk-update <project_num> <owner> <csv_file> [--dry-run]"
            fi
            local dry_run="false"
            if [ "$5" = "--dry-run" ]; then
                dry_run="true"
            fi
            bulk_update_fields "$2" "$3" "$4" "$dry_run"
            ;;
        *)
            if [ -z "$command" ]; then
                show_usage
                exit 0
            else
                error_exit "Unknown command: $command. Use '$0 --help' for usage information."
            fi
            ;;
    esac
}

# Handle script interruption
trap 'echo -e "\n${YELLOW}Script interrupted${NC}"; exit 130' INT TERM

# Run main function
main "$@"