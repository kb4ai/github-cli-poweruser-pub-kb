#!/bin/bash
#
# GitHub Projects Field Discovery - Field Inspection and Schema Tools
# 
# This script provides comprehensive field discovery and inspection capabilities
# for GitHub Projects. It can list fields, get field details, export schemas,
# and validate field configurations.
#
# Usage Examples:
#   ./github-projects-field-discovery.sh list-fields 1 AcmeInc
#   ./github-projects-field-discovery.sh get-field-details 1 AcmeInc "Status"
#   ./github-projects-field-discovery.sh export-schema 1 AcmeInc json
#   ./github-projects-field-discovery.sh validate-field 1 AcmeInc "Priority" "High"
#
# Requirements:
# - GitHub CLI (gh) with authentication
# - read:project scope
# - jq for JSON processing
#

set -e

# Script configuration
VERSION="1.0.0"
SCRIPT_NAME="github-projects-field-discovery"
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
    
    # Check for project scope
    if ! gh auth status 2>&1 | grep -q "project\|read:project"; then
        warning "Project scope may not be available. Consider running: gh auth refresh -s project --hostname github.com"
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

# Get comprehensive project field information
get_project_fields() {
    local project_num="$1"
    local owner="$2"
    
    # Get project ID
    local project_id
    project_id=$(get_project_id "$project_num" "$owner")
    
    # Query all field types
    local query='query($projectId: ID!) {
        node(id: $projectId) {
            ... on ProjectV2 {
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
                                color
                                description
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
                                    startDate
                                    duration
                                }
                                completedIterations {
                                    id
                                    title
                                    startDate
                                    duration
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
    
    echo "$result"
}

# List all fields in the project
list_project_fields() {
    local project_num="$1"
    local owner="$2"
    local format="${3:-table}"
    
    info "Listing fields in project $project_num (owner: $owner)"
    
    local result
    result=$(get_project_fields "$project_num" "$owner")
    
    if [ "$format" = "json" ]; then
        echo "$result" | jq '.'
        return
    fi
    
    if [ "$format" = "csv" ]; then
        echo "Field ID,Field Name,Data Type,Options/Configuration"
        echo "$result" | jq -r '
        .data.node.fields.nodes[] |
        [
            .id,
            .name,
            .dataType,
            (if .options then ([.options[].name] | join(";")) 
             elif .configuration.iterations then ([.configuration.iterations[].title] | join(";"))
             else "N/A" end)
        ] | @csv'
        return
    fi
    
    # Table format (default)
    local project_title
    project_title=$(echo "$result" | jq -r '.data.node.title')
    
    echo -e "\n${BLUE}=== Project Fields: $project_title ===${NC}"
    echo
    
    local field_count
    field_count=$(echo "$result" | jq -r '.data.node.fields.nodes | length')
    
    if [ "$field_count" = "0" ]; then
        info "No custom fields found in project"
        return
    fi
    
    printf "%-32s %-20s %-15s %-30s\n" "FIELD ID" "FIELD NAME" "DATA TYPE" "OPTIONS/CONFIG"
    printf "%-32s %-20s %-15s %-30s\n" "$(printf '%.32s' "--------------------------------")" "$(printf '%.20s' "--------------------")" "$(printf '%.15s' "---------------")" "$(printf '%.30s' "------------------------------")"
    
    echo "$result" | jq -r '
    .data.node.fields.nodes[] |
    [
        .id,
        .name,
        .dataType,
        (if .options then ([.options[].name] | join(",") | if length > 27 then .[0:27] + "..." else . end)
         elif .configuration.iterations then ([.configuration.iterations[].title] | join(",") | if length > 27 then .[0:27] + "..." else . end)
         else "N/A" end)
    ] | @tsv' | \
    while IFS=$'\t' read -r field_id field_name data_type options; do
        printf "%-32s %-20s %-15s %-30s\n" "$field_id" "$field_name" "$data_type" "$options"
    done
    
    echo
    success "Listed $field_count fields from project"
}

# Get detailed information about a specific field
get_field_details() {
    local project_num="$1"
    local owner="$2"
    local field_name="$3"
    local format="${4:-detailed}"
    
    info "Getting details for field '$field_name' in project $project_num (owner: $owner)"
    
    local result
    result=$(get_project_fields "$project_num" "$owner")
    
    local field_data
    field_data=$(echo "$result" | jq --arg name "$field_name" '.data.node.fields.nodes[] | select(.name == $name)')
    
    if [ -z "$field_data" ] || [ "$field_data" = "null" ]; then
        error_exit "Field '$field_name' not found in project"
    fi
    
    if [ "$format" = "json" ]; then
        echo "$field_data" | jq '.'
        return
    fi
    
    # Detailed format (default)
    local field_id
    local data_type
    field_id=$(echo "$field_data" | jq -r '.id')
    data_type=$(echo "$field_data" | jq -r '.dataType')
    
    echo -e "\n${BLUE}=== Field Details: $field_name ===${NC}"
    echo -e "${GREEN}Field ID:${NC} $field_id"
    echo -e "${GREEN}Data Type:${NC} $data_type"
    echo
    
    # Handle different field types
    case "$data_type" in
        "SINGLE_SELECT")
            local options
            options=$(echo "$field_data" | jq -r '.options[]?')
            
            if [ -n "$options" ]; then
                echo -e "${GREEN}Select Options:${NC}"
                printf "  %-12s %-20s %-10s %s\n" "OPTION ID" "OPTION NAME" "COLOR" "DESCRIPTION"
                printf "  %-12s %-20s %-10s %s\n" "$(printf '%.12s' "------------")" "$(printf '%.20s' "--------------------")" "$(printf '%.10s' "----------")" "$(printf '%.20s' "--------------------")"
                
                echo "$field_data" | jq -r '.options[] | [.id, .name, (.color // "N/A"), (.description // "N/A")] | @tsv' | \
                while IFS=$'\t' read -r opt_id opt_name color desc; do
                    printf "  %-12s %-20s %-10s %s\n" "$opt_id" "$opt_name" "$color" "$desc"
                done
            else
                warning "No options configured for this single-select field"
            fi
            ;;
        "ITERATION")
            local iterations
            iterations=$(echo "$field_data" | jq -r '.configuration.iterations[]?')
            
            if [ -n "$iterations" ]; then
                echo -e "${GREEN}Active Iterations:${NC}"
                printf "  %-20s %-20s %-12s %s\n" "ITERATION ID" "TITLE" "START DATE" "DURATION"
                printf "  %-20s %-20s %-12s %s\n" "$(printf '%.20s' "--------------------")" "$(printf '%.20s' "--------------------")" "$(printf '%.12s' "------------")" "$(printf '%.10s' "----------")"
                
                echo "$field_data" | jq -r '.configuration.iterations[] | [.id, .title, .startDate, (.duration // "N/A")] | @tsv' | \
                while IFS=$'\t' read -r iter_id title start_date duration; do
                    printf "  %-20s %-20s %-12s %s\n" "$iter_id" "$title" "$start_date" "$duration"
                done
            fi
            
            local completed
            completed=$(echo "$field_data" | jq -r '.configuration.completedIterations[]?')
            
            if [ -n "$completed" ]; then
                echo
                echo -e "${GREEN}Completed Iterations:${NC}"
                printf "  %-20s %-20s %-12s %s\n" "ITERATION ID" "TITLE" "START DATE" "DURATION"
                printf "  %-20s %-20s %-12s %s\n" "$(printf '%.20s' "--------------------")" "$(printf '%.20s' "--------------------")" "$(printf '%.12s' "------------")" "$(printf '%.10s' "----------")"
                
                echo "$field_data" | jq -r '.configuration.completedIterations[] | [.id, .title, .startDate, (.duration // "N/A")] | @tsv' | \
                while IFS=$'\t' read -r iter_id title start_date duration; do
                    printf "  %-20s %-20s %-12s %s\n" "$iter_id" "$title" "$start_date" "$duration"
                done
            fi
            ;;
        *)
            info "Field type $data_type has no additional configuration options"
            ;;
    esac
    
    echo
    success "Retrieved details for field '$field_name'"
}

# Export project schema
export_project_schema() {
    local project_num="$1"
    local owner="$2"
    local format="${3:-json}"
    local output_file="$4"
    
    info "Exporting project schema for project $project_num (owner: $owner) in $format format"
    
    local result
    result=$(get_project_fields "$project_num" "$owner")
    
    local project_title
    project_title=$(echo "$result" | jq -r '.data.node.title')
    
    case "$format" in
        "json")
            local schema
            schema=$(echo "$result" | jq '{
                project: {
                    title: .data.node.title,
                    fields: [
                        .data.node.fields.nodes[] | {
                            id: .id,
                            name: .name,
                            dataType: .dataType,
                            options: (if .options then [.options[] | {id: .id, name: .name, color: .color, description: .description}] else null end),
                            iterations: (if .configuration.iterations then [.configuration.iterations[] | {id: .id, title: .title, startDate: .startDate, duration: .duration}] else null end),
                            completedIterations: (if .configuration.completedIterations then [.configuration.completedIterations[] | {id: .id, title: .title, startDate: .startDate, duration: .duration}] else null end)
                        }
                    ]
                }
            }')
            
            if [ -n "$output_file" ]; then
                echo "$schema" > "$output_file"
                success "Schema exported to $output_file"
            else
                echo "$schema"
            fi
            ;;
        "csv")
            local csv_output
            csv_output="Project Title,Field ID,Field Name,Data Type,Option ID,Option Name,Option Color,Option Description"$'\n'
            
            csv_output+=$(echo "$result" | jq -r --arg title "$project_title" '
            .data.node.fields.nodes[] as $field |
            if $field.options then
                ($field.options[] | [$title, $field.id, $field.name, $field.dataType, .id, .name, (.color // ""), (.description // "")] | @csv)
            else
                [$title, $field.id, $field.name, $field.dataType, "", "", "", ""] | @csv
            end' | tr '\n' '\n')
            
            if [ -n "$output_file" ]; then
                echo "$csv_output" > "$output_file"
                success "Schema exported to $output_file"
            else
                echo "$csv_output"
            fi
            ;;
        "markdown")
            local md_output
            md_output="# Project Schema: $project_title"$'\n\n'
            md_output+="## Fields"$'\n\n'
            
            md_output+=$(echo "$result" | jq -r '
            .data.node.fields.nodes[] |
            "### " + .name + "\n" +
            "- **ID**: `" + .id + "`\n" +
            "- **Type**: " + .dataType + "\n" +
            (if .options then 
                "- **Options**:\n" + 
                (.options[] | "  - `" + .name + "` (" + .id + ")" + (if .color then " - Color: " + .color else "" end) + (if .description then " - " + .description else "" end) + "\n") 
            else "" end) +
            (if .configuration.iterations then 
                "- **Iterations**:\n" + 
                (.configuration.iterations[] | "  - `" + .title + "` (" + .id + ") - Start: " + .startDate + "\n")
            else "" end) +
            "\n"')
            
            if [ -n "$output_file" ]; then
                echo "$md_output" > "$output_file"
                success "Schema exported to $output_file"
            else
                echo "$md_output"
            fi
            ;;
        *)
            error_exit "Unknown format: $format. Supported formats: json, csv, markdown"
            ;;
    esac
}

# Validate field existence and option
validate_field() {
    local project_num="$1"
    local owner="$2"
    local field_name="$3"
    local option_name="$4"
    
    info "Validating field '$field_name' with option '$option_name' in project $project_num (owner: $owner)"
    
    local result
    result=$(get_project_fields "$project_num" "$owner")
    
    local field_data
    field_data=$(echo "$result" | jq --arg name "$field_name" '.data.node.fields.nodes[] | select(.name == $name)')
    
    if [ -z "$field_data" ] || [ "$field_data" = "null" ]; then
        error_exit "❌ Field '$field_name' not found in project"
    fi
    
    success "✅ Field '$field_name' exists"
    
    local field_id
    local data_type
    field_id=$(echo "$field_data" | jq -r '.id')
    data_type=$(echo "$field_data" | jq -r '.dataType')
    
    echo -e "${GREEN}Field ID:${NC} $field_id"
    echo -e "${GREEN}Data Type:${NC} $data_type"
    
    # Validate option if provided
    if [ -n "$option_name" ]; then
        case "$data_type" in
            "SINGLE_SELECT")
                local option_id
                option_id=$(echo "$field_data" | jq -r --arg opt "$option_name" '.options[] | select(.name == $opt) | .id')
                
                if [ -z "$option_id" ] || [ "$option_id" = "null" ]; then
                    error_exit "❌ Option '$option_name' not found in field '$field_name'"
                fi
                
                success "✅ Option '$option_name' exists in field '$field_name'"
                echo -e "${GREEN}Option ID:${NC} $option_id"
                ;;
            "ITERATION")
                local iteration_id
                iteration_id=$(echo "$field_data" | jq -r --arg opt "$option_name" '.configuration.iterations[] | select(.title == $opt) | .id')
                
                if [ -z "$iteration_id" ] || [ "$iteration_id" = "null" ]; then
                    # Check completed iterations too
                    iteration_id=$(echo "$field_data" | jq -r --arg opt "$option_name" '.configuration.completedIterations[] | select(.title == $opt) | .id')
                    
                    if [ -z "$iteration_id" ] || [ "$iteration_id" = "null" ]; then
                        error_exit "❌ Iteration '$option_name' not found in field '$field_name'"
                    fi
                fi
                
                success "✅ Iteration '$option_name' exists in field '$field_name'"
                echo -e "${GREEN}Iteration ID:${NC} $iteration_id"
                ;;
            *)
                warning "Cannot validate options for field type: $data_type"
                ;;
        esac
    fi
    
    echo
    success "Field validation complete"
}

# Find field ID by name
find_field_id() {
    local project_num="$1"
    local owner="$2"
    local field_name="$3"
    
    local result
    result=$(get_project_fields "$project_num" "$owner")
    
    local field_id
    field_id=$(echo "$result" | jq -r --arg name "$field_name" '.data.node.fields.nodes[] | select(.name == $name) | .id')
    
    if [ -z "$field_id" ] || [ "$field_id" = "null" ]; then
        error_exit "Field '$field_name' not found in project"
    fi
    
    echo "$field_id"
}

# Find option ID by field name and option name
find_option_id() {
    local project_num="$1"
    local owner="$2"
    local field_name="$3"
    local option_name="$4"
    
    local result
    result=$(get_project_fields "$project_num" "$owner")
    
    local option_id
    option_id=$(echo "$result" | jq -r --arg field "$field_name" --arg option "$option_name" '.data.node.fields.nodes[] | select(.name == $field) | .options[] | select(.name == $option) | .id')
    
    if [ -z "$option_id" ] || [ "$option_id" = "null" ]; then
        error_exit "Option '$option_name' not found in field '$field_name'"
    fi
    
    echo "$option_id"
}

# Show usage information
show_usage() {
    cat << EOF
${BLUE}GitHub Projects Field Discovery v$VERSION${NC}

${GREEN}DESCRIPTION:${NC}
    Comprehensive field discovery and inspection tools for GitHub Projects.
    Provides detailed information about project fields, options, and configurations.

${GREEN}USAGE:${NC}
    $0 <command> <project_number> <owner> [arguments...]

${GREEN}COMMANDS:${NC}
    ${YELLOW}list-fields${NC} <project_num> <owner> [format]
        List all fields in the project
        Formats: table (default), json, csv
        
    ${YELLOW}get-field-details${NC} <project_num> <owner> <field_name> [format]
        Get detailed information about a specific field
        Formats: detailed (default), json
        
    ${YELLOW}export-schema${NC} <project_num> <owner> [format] [output_file]
        Export complete project field schema
        Formats: json (default), csv, markdown
        
    ${YELLOW}validate-field${NC} <project_num> <owner> <field_name> [option_name]
        Validate field existence and optionally an option/iteration
        
    ${YELLOW}find-field-id${NC} <project_num> <owner> <field_name>
        Get the field ID for a given field name
        
    ${YELLOW}find-option-id${NC} <project_num> <owner> <field_name> <option_name>
        Get the option ID for a given field and option name

${GREEN}EXAMPLES:${NC}
    # List all fields in table format
    $0 list-fields 1 AcmeInc
    
    # Get detailed information about Status field
    $0 get-field-details 1 AcmeInc "Status"
    
    # Export schema as JSON
    $0 export-schema 1 AcmeInc json project_schema.json
    
    # Export schema as Markdown
    $0 export-schema 1 AcmeInc markdown project_fields.md
    
    # Validate field exists
    $0 validate-field 1 AcmeInc "Priority"
    
    # Validate field and option exist
    $0 validate-field 1 AcmeInc "Status" "Done"
    
    # Get field ID
    $0 find-field-id 1 AcmeInc "Status"
    
    # Get option ID  
    $0 find-option-id 1 AcmeInc "Status" "In Progress"

${GREEN}OWNER FORMATS:${NC}
    - Organization: ${YELLOW}orgname${NC}
    - User: ${YELLOW}username${NC}
    - Current user: ${YELLOW}@me${NC}

${GREEN}SUPPORTED FIELD TYPES:${NC}
    - TEXT: Plain text fields
    - NUMBER: Numeric fields
    - DATE: Date fields
    - SINGLE_SELECT: Dropdown with predefined options
    - ITERATION: Sprint/iteration planning fields

${GREEN}REQUIREMENTS:${NC}
    - GitHub CLI (gh) installed and authenticated
    - Project scopes: read:project
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
        list-fields)
            if [ $# -lt 3 ]; then
                error_exit "Usage: $0 list-fields <project_num> <owner> [format]"
            fi
            list_project_fields "$2" "$3" "${4:-table}"
            ;;
        get-field-details)
            if [ $# -lt 4 ]; then
                error_exit "Usage: $0 get-field-details <project_num> <owner> <field_name> [format]"
            fi
            get_field_details "$2" "$3" "$4" "${5:-detailed}"
            ;;
        export-schema)
            if [ $# -lt 3 ]; then
                error_exit "Usage: $0 export-schema <project_num> <owner> [format] [output_file]"
            fi
            export_project_schema "$2" "$3" "${4:-json}" "$5"
            ;;
        validate-field)
            if [ $# -lt 4 ]; then
                error_exit "Usage: $0 validate-field <project_num> <owner> <field_name> [option_name]"
            fi
            validate_field "$2" "$3" "$4" "$5"
            ;;
        find-field-id)
            if [ $# -ne 4 ]; then
                error_exit "Usage: $0 find-field-id <project_num> <owner> <field_name>"
            fi
            find_field_id "$2" "$3" "$4"
            ;;
        find-option-id)
            if [ $# -ne 5 ]; then
                error_exit "Usage: $0 find-option-id <project_num> <owner> <field_name> <option_name>"
            fi
            find_option_id "$2" "$3" "$4" "$5"
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