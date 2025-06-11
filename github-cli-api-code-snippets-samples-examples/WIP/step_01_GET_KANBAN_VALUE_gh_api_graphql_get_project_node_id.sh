#!/bin/bash

# Please provide project id as parameter , otherwise use default one.

if [ "$1" == '-h' ]; then
	echo -e "Usage:-n$0 [PROJECT_ID [FIELD_NAME]] # otherwise will use defaults"
	exit
fi
PROJECT_ID="${1:-PVT_kwExampleProjectID}"
FIELD_NAME="${2:-Status}"
#FIELD_NAME="${2:-TestField}"

gh api graphql -f query='
  query{
    node(id: "'"${PROJECT_ID}"'") {
        ... on ProjectV2 {
          items(first: 8) {
            nodes{
              id
              fieldValues(first: 8) {
                nodes{                
                  ... on ProjectV2ItemFieldTextValue {
                    text
                    field {
                      ... on ProjectV2FieldCommon {
                        name
			id
                      }
                    }
                  }
                  ... on ProjectV2ItemFieldDateValue {
                    date
                    field {
                      ... on ProjectV2FieldCommon {
		        name
			id
                      }
                    }
                  }
                  ... on ProjectV2ItemFieldSingleSelectValue {
                    name
                    field {
                      ... on ProjectV2FieldCommon {
                        name
			id
                      }
                    }
                  }
                  ... on ProjectV2ItemFieldSingleSelectValue {
                    name
                    field {
                      ... on ProjectV2FieldCommon {
                        name
			id
                      }
                    }
                  }
                }              
              }
              content{              
                ... on DraftIssue {
                  title
                  body
                }
                ...on Issue {
                  title
                  assignees(first: 10) {
                    nodes{
                      login
                    }
                  }
                }
                ...on PullRequest {
                  title
                  assignees(first: 10) {
                    nodes{
                      login
                    }
                  }
                }
              }
              fieldValueByName(name: "'"${FIELD_NAME}"'") {
                ... on ProjectV2ItemFieldSingleSelectValue {
                  name
		  id
                }
              }
            }
          }
        }
      }
    }'

