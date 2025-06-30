#!/bin/bash
#
# GitHub Projects Field Creation and Management
# 
# This script provides comprehensive field creation and management capabilities
# for GitHub Projects v2. Supports all field types and CRUD operations for options.
#
# Usage Examples:
#   ./github-projects-field-creation.sh create-text-field 1 AcmeInc "Description"
#   ./github-projects-field-creation.sh create-select-field 1 AcmeInc "Priority" "Low,Medium,High"
#   ./github-projects-field-creation.sh create-number-field 1 AcmeInc "Story Points"
#   ./github-projects-field-creation.sh add-select-option 1 AcmeInc "Priority" "Critical"
#   ./github-projects-field-creation.sh delete-field 1 AcmeInc "Old Field"
#
# Requirements:
# - GitHub CLI (gh) with authentication
# - project scope (write access required)
# - jq for JSON processing
#

set -e

# Script configuration
VERSION="1.0.0"
SCRIPT_NAME="github-projects-field-creation"
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
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
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
        
        local output
        if output=$(eval "$cmd" 2>/dev/null); then
            echo "$output"
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
    # Check for classic token file first
    local token_file="${GITHUB_TOKEN_DOTFILE}"
    if [ -f "$token_file" ]; then
        source "$token_file"
        export GH_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN"
        info "Using classic token from configured file"
    fi
    
    if ! gh auth status >/dev/null 2>&1; then
        error_exit "GitHub CLI not authenticated. Please run: gh auth login --scopes project"
    fi
    
    # Check for project scope
    if ! gh auth status 2>&1 | grep -q "project"; then
        warning "Project scope may not be available. Consider running: gh auth refresh -s project --hostname github.com"
        info "You may need to manually authorize project access at: https://github.com/settings/tokens"
    fi
    
    success "Project authentication validated"
}

# Get project ID from project number and owner
get_project_id() {
    local project_num="$1"
    local owner="$2"
    
    local project_id
    if [[ "$owner" == *"/"* ]]; then
        # User project
        local username=$(echo "$owner" | cut -d'/' -f1)
        project_id=$(gh api graphql -f query="query{ user(login: \"$username\"){ projectV2(number: $project_num) { id } } }" | jq -r '.data.user.projectV2.id')
    else
        # Organization project
        project_id=$(gh api graphql -f query="query{ organization(login: \"$owner\"){ projectV2(number: $project_num) { id } } }" | jq -r '.data.organization.projectV2.id')
    fi
    
    if [ -z "$project_id" ] || [ "$project_id" = "null" ]; then
        error_exit "Could not find project $project_num for owner $owner"
    fi
    
    echo "$project_id"
}

# Get field ID by name
get_field_id_by_name() {
    local project_num="$1"
    local owner="$2" 
    local field_name="$3"
    
    local project_id
    project_id=$(get_project_id "$project_num" "$owner")
    
    local field_query
    if [[ "$owner" == *"/"* ]]; then
        # User project
        local username=$(echo "$owner" | cut -d'/' -f1)
        field_query='query{ user(login: "'$username'"){ projectV2(number: '$project_num') { fields(first: 50) { nodes { ... on ProjectV2Field { id name } ... on ProjectV2SingleSelectField { id name } ... on ProjectV2IterationField { id name } } } } } }'
    else
        # Organization project
        field_query='query{ organization(login: "'$owner'"){ projectV2(number: '$project_num') { fields(first: 50) { nodes { ... on ProjectV2Field { id name } ... on ProjectV2SingleSelectField { id name } ... on ProjectV2IterationField { id name } } } } } }'
    fi
    
    local field_id
    if [[ "$owner" == *"/"* ]]; then
        field_id=$(gh api graphql -f query="$field_query" | jq -r ".data.user.projectV2.fields.nodes[] | select(.name == \"$field_name\") | .id")
    else
        field_id=$(gh api graphql -f query="$field_query" | jq -r ".data.organization.projectV2.fields.nodes[] | select(.name == \"$field_name\") | .id")
    fi
    
    echo "$field_id"
}

# Create text field
create_text_field() {
    local project_num="$1"
    local owner="$2"
    local field_name="$3"
    
    info "Creating text field '$field_name' in project $project_num (owner: $owner)"
    
    # Get project ID
    local project_id
    project_id=$(get_project_id "$project_num" "$owner")
    info "Project ID: $project_id"
    
    # Create text field
    local mutation='mutation {
        createProjectV2Field(input: {
            projectId: "'$project_id'"
            dataType: TEXT
            name: "'$field_name'"
        }) {
            projectV2Field {
                ... on ProjectV2Field {
                    id
                    name
                    dataType
                }
            }
        }
    }'
    
    local result
    result=$(gh api graphql -f query="$mutation")
    
    local field_id
    field_id=$(echo "$result" | jq -r '.data.createProjectV2Field.projectV2Field.id')
    
    if [ -z "$field_id" ] || [ "$field_id" = "null" ]; then
        error_exit "Failed to create text field: $(echo "$result" | jq -r '.errors[]?.message' | head -1)"
    fi
    
    success "Created text field '$field_name' (ID: $field_id)"
    echo "$field_id"
}

# Create number field
create_number_field() {
    local project_num="$1"
    local owner="$2"
    local field_name="$3"
    
    info "Creating number field '$field_name' in project $project_num (owner: $owner)"
    
    # Get project ID
    local project_id
    project_id=$(get_project_id "$project_num" "$owner")
    
    # Create number field
    local mutation='mutation {
        createProjectV2Field(input: {
            projectId: "'$project_id'"
            dataType: NUMBER
            name: "'$field_name'"
        }) {
            projectV2Field {
                ... on ProjectV2Field {
                    id
                    name
                    dataType
                }
            }
        }
    }'
    
    local result
    result=$(gh api graphql -f query="$mutation")
    
    local field_id
    field_id=$(echo "$result" | jq -r '.data.createProjectV2Field.projectV2Field.id')
    
    if [ -z "$field_id" ] || [ "$field_id" = "null" ]; then
        error_exit "Failed to create number field: $(echo "$result" | jq -r '.errors[]?.message' | head -1)"
    fi
    
    success "Created number field '$field_name' (ID: $field_id)"
    echo "$field_id"
}

# Create date field
create_date_field() {
    local project_num="$1"
    local owner="$2"
    local field_name="$3"
    
    info "Creating date field '$field_name' in project $project_num (owner: $owner)"
    
    # Get project ID
    local project_id
    project_id=$(get_project_id "$project_num" "$owner")
    
    # Create date field
    local mutation='mutation {
        createProjectV2Field(input: {
            projectId: "'$project_id'"
            dataType: DATE
            name: "'$field_name'"
        }) {
            projectV2Field {
                ... on ProjectV2Field {
                    id
                    name
                    dataType
                }
            }
        }
    }'
    
    local result
    result=$(gh api graphql -f query="$mutation")
    
    local field_id
    field_id=$(echo "$result" | jq -r '.data.createProjectV2Field.projectV2Field.id')
    
    if [ -z "$field_id" ] || [ "$field_id" = "null" ]; then
        error_exit "Failed to create date field: $(echo "$result" | jq -r '.errors[]?.message' | head -1)"
    fi
    
    success "Created date field '$field_name' (ID: $field_id)"
    echo "$field_id"
}

# Create single select field with options
create_select_field() {
    local project_num="$1"
    local owner="$2"
    local field_name="$3"
    local options_csv="$4"  # Comma-separated list of options
    
    info "Creating single select field '$field_name' with options: $options_csv"
    
    # Get project ID
    local project_id
    project_id=$(get_project_id "$project_num" "$owner")
    
    # Build options array for GraphQL
    local options_graphql=""
    IFS=',' read -ra ADDR <<< "$options_csv"
    for option in "${ADDR[@]}"; do
        option=$(echo "$option" | xargs)  # trim whitespace
        if [ -n "$options_graphql" ]; then
            options_graphql="$options_graphql, "
        fi
        options_graphql="$options_graphql{name: \"$option\", description: \"$option\", color: GRAY}"
    done
    
    # Create single select field with options
    local mutation="mutation {
        createProjectV2Field(input: {
            projectId: \"$project_id\"
            dataType: SINGLE_SELECT
            name: \"$field_name\"
            singleSelectOptions: [$options_graphql]
        }) {
            projectV2Field {
                ... on ProjectV2SingleSelectField {
                    id
                    name
                    dataType
                    options {
                        id
                        name
                    }
                }
            }
        }
    }"
    
    local result
    result=$(gh api graphql -f query="$mutation")
    
    local field_id
    field_id=$(echo "$result" | jq -r '.data.createProjectV2Field.projectV2Field.id')
    
    if [ -z "$field_id" ] || [ "$field_id" = "null" ]; then
        error_exit "Failed to create single select field: $(echo "$result" | jq -r '.errors[]?.message' | head -1)"
    fi
    
    local option_count
    option_count=$(echo "$result" | jq -r '.data.createProjectV2Field.projectV2Field.options | length')
    
    success "Created single select field '$field_name' with $option_count options (ID: $field_id)"
    echo "$field_id"
}

# Create iteration field
create_iteration_field() {
    local project_num="$1"
    local owner="$2"
    local field_name="$3"
    
    info "Creating iteration field '$field_name' in project $project_num (owner: $owner)"
    
    # Get project ID
    local project_id
    project_id=$(get_project_id "$project_num" "$owner")
    
    # Create iteration field with default configuration
    local mutation='mutation {
        createProjectV2Field(input: {
            projectId: "'$project_id'"
            dataType: ITERATION
            name: "'$field_name'"
        }) {
            projectV2Field {
                ... on ProjectV2IterationField {
                    id
                    name
                    dataType
                    configuration {
                        duration
                        startDay
                    }
                }
            }
        }
    }'
    
    local result
    result=$(gh api graphql -f query="$mutation")
    
    local field_id
    field_id=$(echo "$result" | jq -r '.data.createProjectV2Field.projectV2Field.id')
    
    if [ -z "$field_id" ] || [ "$field_id" = "null" ]; then
        error_exit "Failed to create iteration field: $(echo "$result" | jq -r '.errors[]?.message' | head -1)"
    fi
    
    success "Created iteration field '$field_name' (ID: $field_id)"
    echo "$field_id"
}

# Add option to single select field
add_select_option() {
    local project_num="$1"
    local owner="$2"
    local field_name="$3"
    local option_name="$4"
    local color="${5:-GRAY}"  # Default color
    
    info "Adding option '$option_name' to field '$field_name'"
    
    # Get project ID and field ID
    local project_id
    project_id=$(get_project_id "$project_num" "$owner")
    
    local field_id
    field_id=$(get_field_id_by_name "$project_num" "$owner" "$field_name")
    
    if [ -z "$field_id" ] || [ "$field_id" = "null" ]; then
        error_exit "Could not find field '$field_name'"
    fi
    
    # Add option to single select field  
    local mutation='mutation {
        updateProjectV2Field(input: {
            fieldId: "'$field_id'"
            singleSelectOptions: [{
                name: "'$option_name'"
                description: "'$option_name'"
                color: '$color'
            }]
        }) {
            projectV2Field {
                ... on ProjectV2SingleSelectField {
                    id
                    options {
                        id
                        name
                    }
                }
            }
        }
    }'
    
    local result
    result=$(gh api graphql -f query="$mutation")
    
    local option_id
    option_id=$(echo "$result" | jq -r ".data.updateProjectV2Field.projectV2Field.options[] | select(.name == \"$option_name\") | .id")
    
    if [ -z "$option_id" ] || [ "$option_id" = "null" ]; then
        error_exit "Failed to add option to field: $(echo "$result" | jq -r '.errors[]?.message' | head -1)"
    fi
    
    success "Added option '$option_name' to field '$field_name' (Option ID: $option_id)"
    echo "$option_id"
}

# Delete field
delete_field() {
    local project_num="$1"
    local owner="$2"
    local field_name="$3"
    
    info "Deleting field '$field_name' from project $project_num (owner: $owner)"
    
    # Get field ID
    local field_id
    field_id=$(get_field_id_by_name "$project_num" "$owner" "$field_name")
    
    if [ -z "$field_id" ] || [ "$field_id" = "null" ]; then
        error_exit "Could not find field '$field_name'"
    fi
    
    # Delete field
    local mutation='mutation {
        deleteProjectV2Field(input: {
            fieldId: "'$field_id'"
        }) {
            projectV2Field {
                ... on ProjectV2Field {
                    id
                    name
                }
                ... on ProjectV2SingleSelectField {
                    id
                    name
                }
                ... on ProjectV2IterationField {
                    id
                    name
                }
            }
        }
    }'
    
    local result
    result=$(gh api graphql -f query="$mutation")
    
    local deleted_id
    deleted_id=$(echo "$result" | jq -r '.data.deleteProjectV2Field.projectV2Field.id')
    
    if [ -z "$deleted_id" ] || [ "$deleted_id" = "null" ]; then
        error_exit "Failed to delete field: $(echo "$result" | jq -r '.errors[]?.message' | head -1)"
    fi
    
    success "Deleted field '$field_name' (ID: $deleted_id)"
}

# List all fields with details
list_all_fields() {
    local project_num="$1"
    local owner="$2"
    local format="${3:-table}"
    
    info "Listing all fields in project $project_num (owner: $owner)"
    
    # Get project fields
    local query
    if [[ "$owner" == *"/"* ]]; then
        # User project
        local username=$(echo "$owner" | cut -d'/' -f1)
        query='query{ user(login: "'$username'"){ projectV2(number: '$project_num') { 
            title
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
                            duration
                            startDay
                        }
                    }
                } 
            } 
        } } }'
    else
        # Organization project
        query='query{ organization(login: "'$owner'"){ projectV2(number: '$project_num') { 
            title
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
                            duration
                            startDay
                        }
                    }
                } 
            } 
        } } }'
    fi
    
    local result
    result=$(gh api graphql -f query="$query")
    
    if [ "$format" = "json" ]; then
        echo "$result" | jq '.data'
        return
    fi
    
    # Table format
    local project_title
    if [[ "$owner" == *"/"* ]]; then
        project_title=$(echo "$result" | jq -r '.data.user.projectV2.title')
    else
        project_title=$(echo "$result" | jq -r '.data.organization.projectV2.title')
    fi
    
    echo
    echo -e "${BLUE}=== Project: $project_title ===${NC}"
    echo
    
    printf "%-35s %-20s %-15s %-30s\n" "FIELD ID" "NAME" "TYPE" "OPTIONS/CONFIG"
    printf "%-35s %-20s %-15s %-30s\n" "$(printf '%.35s' "-----------------------------------")" "$(printf '%.20s' "--------------------")" "$(printf '%.15s' "---------------")" "$(printf '%.30s' "------------------------------")"
    
    if [[ "$owner" == *"/"* ]]; then
        echo "$result" | jq -r '.data.user.projectV2.fields.nodes[] |
        [
            .id,
            .name,
            .dataType,
            (if .options then ([.options[].name] | join(", ")) elif .configuration then ("Duration: " + (.configuration.duration | tostring) + " days") else "N/A" end)
        ] | @tsv' | \
        while IFS=$'\t' read -r field_id name data_type options; do
            printf "%-35s %-20s %-15s %-30s\n" "$field_id" "$name" "$data_type" "$options"
        done
    else
        echo "$result" | jq -r '.data.organization.projectV2.fields.nodes[] |
        [
            .id,
            .name,
            .dataType,
            (if .options then ([.options[].name] | join(", ")) elif .configuration then ("Duration: " + (.configuration.duration | tostring) + " days") else "N/A" end)
        ] | @tsv' | \
        while IFS=$'\t' read -r field_id name data_type options; do
            printf "%-35s %-20s %-15s %-30s\n" "$field_id" "$name" "$data_type" "$options"
        done
    fi
    
    echo
}

# Show usage information
show_usage() {
    cat << EOF
${BLUE}GitHub Projects Field Creation v$VERSION${NC}

${GREEN}DESCRIPTION:${NC}
    Comprehensive field creation and management for GitHub Projects v2.
    Supports all field types and CRUD operations for select field options.

${GREEN}USAGE:${NC}
    $0 <command> <project_number> <owner> [arguments...]

${GREEN}FIELD CREATION COMMANDS:${NC}
    ${YELLOW}create-text-field${NC} <project_num> <owner> <field_name>
        Create a text field for free-form text input
        
    ${YELLOW}create-number-field${NC} <project_num> <owner> <field_name>
        Create a number field for numeric values
        
    ${YELLOW}create-date-field${NC} <project_num> <owner> <field_name>
        Create a date field for date values
        
    ${YELLOW}create-select-field${NC} <project_num> <owner> <field_name> <options_csv>
        Create a single select field with comma-separated options
        
    ${YELLOW}create-iteration-field${NC} <project_num> <owner> <field_name>
        Create an iteration field for sprint planning

${GREEN}FIELD MANAGEMENT COMMANDS:${NC}
    ${YELLOW}add-select-option${NC} <project_num> <owner> <field_name> <option_name> [color]
        Add an option to an existing single select field
        
    ${YELLOW}delete-field${NC} <project_num> <owner> <field_name>
        Delete a field from the project
        
    ${YELLOW}list-fields${NC} <project_num> <owner> [format]
        List all fields in the project (table|json)

${GREEN}EXAMPLES:${NC}
    # Create different field types
    $0 create-text-field 1 AcmeInc "Description"
    $0 create-number-field 1 AcmeInc "Story Points"
    $0 create-date-field 1 AcmeInc "Due Date"
    $0 create-select-field 1 AcmeInc "Priority" "Low,Medium,High,Critical"
    $0 create-iteration-field 1 AcmeInc "Sprint"
    
    # Manage select field options
    $0 add-select-option 1 AcmeInc "Priority" "Urgent" "RED"
    
    # Field management
    $0 list-fields 1 AcmeInc
    $0 delete-field 1 AcmeInc "Old Field"

${GREEN}FIELD TYPES:${NC}
    - ${YELLOW}TEXT${NC}: Free-form text input
    - ${YELLOW}NUMBER${NC}: Numeric values (integers or decimals)
    - ${YELLOW}DATE${NC}: Date values in YYYY-MM-DD format
    - ${YELLOW}SINGLE_SELECT${NC}: Dropdown with predefined options
    - ${YELLOW}ITERATION${NC}: Sprint/iteration planning (2-week cycles)

${GREEN}SELECT FIELD COLORS:${NC}
    GRAY, RED, ORANGE, YELLOW, GREEN, BLUE, PURPLE, PINK

${GREEN}OWNER FORMATS:${NC}
    - Organization: ${YELLOW}orgname${NC}
    - User: ${YELLOW}username${NC}
    - Current user: ${YELLOW}@me${NC}

${GREEN}REQUIREMENTS:${NC}
    - GitHub CLI (gh) installed and authenticated
    - Project scopes: project (write access required)
    - jq for JSON processing
    - Internet connection

${GREEN}FILES:${NC}
    Log file: $LOG_FILE
    
${GREEN}AUTHENTICATION:${NC}
    Classic token: \${GITHUB_TOKEN_DOTFILE} (required)
    Or run: gh auth refresh -s project --hostname github.com
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
        create-text-field)
            if [ $# -ne 4 ]; then
                error_exit "Usage: $0 create-text-field <project_num> <owner> <field_name>"
            fi
            create_text_field "$2" "$3" "$4"
            ;;
        create-number-field)
            if [ $# -ne 4 ]; then
                error_exit "Usage: $0 create-number-field <project_num> <owner> <field_name>"
            fi
            create_number_field "$2" "$3" "$4"
            ;;
        create-date-field)
            if [ $# -ne 4 ]; then
                error_exit "Usage: $0 create-date-field <project_num> <owner> <field_name>"
            fi
            create_date_field "$2" "$3" "$4"
            ;;
        create-select-field)
            if [ $# -ne 5 ]; then
                error_exit "Usage: $0 create-select-field <project_num> <owner> <field_name> <options_csv>"
            fi
            create_select_field "$2" "$3" "$4" "$5"
            ;;
        create-iteration-field)
            if [ $# -ne 4 ]; then
                error_exit "Usage: $0 create-iteration-field <project_num> <owner> <field_name>"
            fi
            create_iteration_field "$2" "$3" "$4"
            ;;
        add-select-option)
            if [ $# -lt 5 ] || [ $# -gt 6 ]; then
                error_exit "Usage: $0 add-select-option <project_num> <owner> <field_name> <option_name> [color]"
            fi
            add_select_option "$2" "$3" "$4" "$5" "${6:-GRAY}"
            ;;
        delete-field)
            if [ $# -ne 4 ]; then
                error_exit "Usage: $0 delete-field <project_num> <owner> <field_name>"
            fi
            delete_field "$2" "$3" "$4"
            ;;
        list-fields)
            if [ $# -lt 3 ]; then
                error_exit "Usage: $0 list-fields <project_num> <owner> [format]"
            fi
            list_all_fields "$2" "$3" "${4:-table}"
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