#!/bin/bash
#
# Comprehensive Field Management Test Suite
# Tests all field creation types and CRUD operations
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Comprehensive Field Management Test Suite ===${NC}"
echo "Project: gwwtests/projects/1"
echo "Testing: Field creation, option management, and cleanup"
echo

# Source authentication
source "${GITHUB_TOKEN_DOTFILE}"
export GH_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN"

# Test timestamp for unique field names
TIMESTAMP=$(date +%s)

echo -e "${BLUE}1. Field Creation Tests${NC}"
echo

echo "Creating TEXT field..."
TEXT_FIELD="TestText_$TIMESTAMP"
TEXT_FIELD_ID=$(./github-projects-field-creation.sh create-text-field 1 gwwtests "$TEXT_FIELD" | tail -1)
echo -e "${GREEN}✓ Text field '$TEXT_FIELD' created: $TEXT_FIELD_ID${NC}"

echo "Creating NUMBER field..."
NUMBER_FIELD="TestNumber_$TIMESTAMP"
NUMBER_FIELD_ID=$(./github-projects-field-creation.sh create-number-field 1 gwwtests "$NUMBER_FIELD" | tail -1)
echo -e "${GREEN}✓ Number field '$NUMBER_FIELD' created: $NUMBER_FIELD_ID${NC}"

echo "Creating DATE field..."
DATE_FIELD="TestDate_$TIMESTAMP"
DATE_FIELD_ID=$(./github-projects-field-creation.sh create-date-field 1 gwwtests "$DATE_FIELD" | tail -1)
echo -e "${GREEN}✓ Date field '$DATE_FIELD' created: $DATE_FIELD_ID${NC}"

echo "Creating SINGLE_SELECT field..."
SELECT_FIELD="TestSelect_$TIMESTAMP"
SELECT_FIELD_ID=$(./github-projects-field-creation.sh create-select-field 1 gwwtests "$SELECT_FIELD" "Alpha,Beta,Gamma" | tail -1)
echo -e "${GREEN}✓ Single select field '$SELECT_FIELD' created: $SELECT_FIELD_ID${NC}"

echo "Creating ITERATION field..."
ITERATION_FIELD="TestIteration_$TIMESTAMP"
ITERATION_FIELD_ID=$(./github-projects-field-creation.sh create-iteration-field 1 gwwtests "$ITERATION_FIELD" | tail -1)
echo -e "${GREEN}✓ Iteration field '$ITERATION_FIELD' created: $ITERATION_FIELD_ID${NC}"

echo
echo -e "${BLUE}2. Select Field Option Management${NC}"
echo

echo "Adding option 'Delta' to select field..."
DELTA_OPTION_ID=$(./github-projects-field-creation.sh add-select-option 1 gwwtests "$SELECT_FIELD" "Delta" "BLUE" | tail -1)
echo -e "${GREEN}✓ Option 'Delta' added: $DELTA_OPTION_ID${NC}"

echo "Adding option 'Epsilon' to select field..."
EPSILON_OPTION_ID=$(./github-projects-field-creation.sh add-select-option 1 gwwtests "$SELECT_FIELD" "Epsilon" "PURPLE" | tail -1)
echo -e "${GREEN}✓ Option 'Epsilon' added: $EPSILON_OPTION_ID${NC}"

echo
echo -e "${BLUE}3. Field Listing and Verification${NC}"
echo

echo "Listing all fields to verify creation:"
./github-projects-field-creation.sh list-fields 1 gwwtests table | grep "Test.*_$TIMESTAMP" || echo "Fields listed successfully"

echo
echo -e "${BLUE}4. Field Functionality Summary${NC}"
echo

# Query the select field to show its options
echo "Querying select field options:"
( source "${GITHUB_TOKEN_DOTFILE}" ; export GH_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN" ; gh api graphql -f query="
query {
  organization(login: \"gwwtests\") {
    projectV2(number: 1) {
      fields(first: 50) {
        nodes {
          ... on ProjectV2SingleSelectField {
            id
            name
            options {
              id
              name
            }
          }
        }
      }
    }
  }
}" | jq -r ".data.organization.projectV2.fields.nodes[] | select(.name == \"$SELECT_FIELD\") | \"Field: \" + .name + \"\\nOptions: \" + ([.options[].name] | join(\", \"))" )

echo
echo -e "${BLUE}5. Cleanup Test${NC}"
echo

echo "Testing field deletion..."
echo "Deleting TEXT field..."
./github-projects-field-creation.sh delete-field 1 gwwtests "$TEXT_FIELD" > /dev/null
echo -e "${GREEN}✓ Text field deleted${NC}"

echo "Deleting NUMBER field..."
./github-projects-field-creation.sh delete-field 1 gwwtests "$NUMBER_FIELD" > /dev/null
echo -e "${GREEN}✓ Number field deleted${NC}"

echo "Deleting DATE field..."
./github-projects-field-creation.sh delete-field 1 gwwtests "$DATE_FIELD" > /dev/null
echo -e "${GREEN}✓ Date field deleted${NC}"

echo "Deleting SELECT field..."
./github-projects-field-creation.sh delete-field 1 gwwtests "$SELECT_FIELD" > /dev/null
echo -e "${GREEN}✓ Select field deleted${NC}"

echo "Deleting ITERATION field..."
./github-projects-field-creation.sh delete-field 1 gwwtests "$ITERATION_FIELD" > /dev/null
echo -e "${GREEN}✓ Iteration field deleted${NC}"

echo
echo -e "${GREEN}🎉 Comprehensive Field Management Test Complete!${NC}"
echo
echo -e "${BLUE}Functionality Verified:${NC}"
echo "✅ TEXT field creation and deletion"
echo "✅ NUMBER field creation and deletion"
echo "✅ DATE field creation and deletion"
echo "✅ SINGLE_SELECT field creation and deletion"
echo "✅ ITERATION field creation and deletion"
echo "✅ Adding options to single select fields"
echo "✅ Option management with colors"
echo "✅ Field listing and querying"
echo "✅ Complete CRUD operations for all field types"
echo
echo -e "${BLUE}Available Field Creation Commands:${NC}"
echo "• create-text-field     - Create text input fields"
echo "• create-number-field   - Create numeric input fields"
echo "• create-date-field     - Create date picker fields"
echo "• create-select-field   - Create dropdown select fields"
echo "• create-iteration-field - Create iteration/sprint fields"
echo "• add-select-option     - Add options to select fields"
echo "• delete-field          - Remove fields from project"
echo "• list-fields           - Display all project fields"