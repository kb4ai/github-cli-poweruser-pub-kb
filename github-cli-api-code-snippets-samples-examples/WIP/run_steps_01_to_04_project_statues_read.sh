#!/bin/bash

PROJECT_ID="${1:-PVT_kwExampleProjectID}"
FIELD_NAME="${2:-Status}"
#FIELD_NAME="${2:-TestField}"

echo '## Select Options Available and Their IDs (in case we would like to run mutation)'
./step_03_GET_KANBAN_SINGLE_SELECT_FIELD_IDS.sh "${PROJECT_ID}" | python step_04_extract_from_03_CSV_with_Single_Select_Option_IDS.py |csview

echo
echo '## List of Statuses of Fields'
./step_01_GET_KANBAN_VALUE_gh_api_graphql_get_project_node_id.sh "${PROJECT_ID}" "${FIELD_NAME}" | python step_02_extract_from_01_CSV_with_Cards_Status.py  | csview 

