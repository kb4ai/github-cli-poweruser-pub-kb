#!/bin/bash

# Please provide project id as parameter , otherwise use default one.

if [ "$1" == '-h' ]; then
	#echo -e "Usage:-n$0 [PROJECT_ID [FIELD_NAME]] # otherwise will use defaults"
	echo -e "Usage:-n$0 [PROJECT_ID] # otherwise will use defaults"
	exit
fi
PROJECT_ID="${1:-PVT_kwExampleProjectID}"
#FIELD_NAME="${2:-Status}"
#FIELD_NAME="${2:-TestField}"

gh api graphql -f query='
  query {
    node(id: "'"${PROJECT_ID}"'") {
      ... on ProjectV2 {
        fields(first: 100) {
          nodes {
            ... on ProjectV2SingleSelectField {
              name
	      id
              options {
                  id
                  name
              }
            }
          }
        }
      }
    }
  }
'
