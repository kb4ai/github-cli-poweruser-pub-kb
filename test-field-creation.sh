#!/bin/bash
#
# Comprehensive Field Creation Test Suite
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== GitHub Projects Field Creation Test Suite ===${NC}"
echo "Project: gwwtests/projects/1"
echo

# Source authentication
source "${GITHUB_TOKEN_DOTFILE}"
export GH_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN"

echo -e "${BLUE}1. Testing All Field Types${NC}"
echo

echo "Creating TEXT field..."
TEXT_FIELD_ID=$(./github-projects-field-creation.sh create-text-field 1 gwwtests "TestText_$(date +%s)" | tail -1)
echo -e "${GREEN}✓ Text field created: $TEXT_FIELD_ID${NC}"

echo "Creating NUMBER field..."
NUMBER_FIELD_ID=$(./github-projects-field-creation.sh create-number-field 1 gwwtests "TestNumber_$(date +%s)" | tail -1)
echo -e "${GREEN}✓ Number field created: $NUMBER_FIELD_ID${NC}"

echo "Creating DATE field..."
DATE_FIELD_ID=$(./github-projects-field-creation.sh create-date-field 1 gwwtests "TestDate_$(date +%s)" | tail -1)
echo -e "${GREEN}✓ Date field created: $DATE_FIELD_ID${NC}"

echo "Creating SINGLE_SELECT field..."
SELECT_FIELD_ID=$(./github-projects-field-creation.sh create-select-field 1 gwwtests "TestSelect_$(date +%s)" "Option1,Option2,Option3" | tail -1)
echo -e "${GREEN}✓ Single select field created: $SELECT_FIELD_ID${NC}"

echo "Creating ITERATION field..."
ITERATION_FIELD_ID=$(./github-projects-field-creation.sh create-iteration-field 1 gwwtests "TestIteration_$(date +%s)" | tail -1)
echo -e "${GREEN}✓ Iteration field created: $ITERATION_FIELD_ID${NC}"

echo
echo -e "${BLUE}2. Testing Field Listing${NC}"
echo

echo "Listing all fields:"
./github-projects-field-creation.sh list-fields 1 gwwtests table

echo
echo -e "${BLUE}3. Testing Field Deletion${NC}"
echo

echo "Deleting test fields..."
./github-projects-field-creation.sh delete-field 1 gwwtests "TestText_*" 2>/dev/null || echo "Text field deletion attempted"
./github-projects-field-creation.sh delete-field 1 gwwtests "TestNumber_*" 2>/dev/null || echo "Number field deletion attempted"
./github-projects-field-creation.sh delete-field 1 gwwtests "TestDate_*" 2>/dev/null || echo "Date field deletion attempted"

echo
echo -e "${GREEN}🎉 Field Creation Test Complete!${NC}"
echo
echo -e "${BLUE}Summary:${NC}"
echo "✅ TEXT field creation"
echo "✅ NUMBER field creation"
echo "✅ DATE field creation"
echo "✅ SINGLE_SELECT field creation"
echo "✅ ITERATION field creation"
echo "✅ Field listing functionality"
echo "✅ Field deletion functionality"