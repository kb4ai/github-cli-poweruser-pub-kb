#!/bin/bash

# Please provide project id as parameter , otherwise use default one.

if [ "$#" -lt 3 ]; then
	echo -e "Usage:-n$0 FIELD_ID ITEM_ID OPTION_ID  [PROJECT_ID] # otherwise will use defaults"
	exit
fi
FIELD_ID="$1"
ITEM_ID="$2"
OPTION_ID="$3"
PROJECT_ID="${4:-PVT_kwExampleProjectID}"


gh api graphql -f query='
  mutation {
    updateProjectV2ItemFieldValue(
      input: {
        projectId: "'"${PROJECT_ID}"'"
        itemId: "'"${ITEM_ID}"'"
        fieldId: "'"${FIELD_ID}"'"
        value: { 
          singleSelectOptionId: "'"${OPTION_ID}"'"        
        }
      }
    ) {
      projectV2Item {
        id
      }
    }
  }'
