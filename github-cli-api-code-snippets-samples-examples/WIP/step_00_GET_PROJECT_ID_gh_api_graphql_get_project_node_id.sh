#!/bin/bash

# take from parameters "project_number" "organisation" otherwise defaults
# Default: https://github.com/orgs/ExampleOrg/projects/1/views/1
if [ "$1" == "-h" ]; then
	echo -e "Usage:\n$0 [PROJECT_NUMBER [ORGANISATION]] # otherwise defaults"
	exit
fi
PROJECT_NUMBER="${1:-1}"
ORGANIZATION="${2:-ExampleOrg}"

# Finding information about projects
# from: https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-api-to-manage-projects#finding-the-node-id-of-an-organization-project

gh api graphql -f query='
  query{
    organization(login: "'"${ORGANIZATION}"'"){
      projectV2(number: '"${PROJECT_NUMBER}"') {
        id
      }
    }
  }'

# Finding the node ID of a user project
# https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-api-to-manage-projects#finding-the-node-id-of-a-user-project
# 
# gh api graphql -f query='
#   query{
#     user(login: "USER"){
#       projectV2(number: NUMBER) {
#         id
#       }
#     }
#   }'


# Also listing projects example from documentation:
# 
# gh api graphql -f query='
#   query{
#     organization(login: "ORGANIZATION") {
#       projectsV2(first: 20) {
#         nodes {
#           id
#           title
#         }
#       }
#     }
#   }'
#
#   # OR FOR USER
#
# gh api graphql -f query='
#   query{
#     user(login: "USER") {
#       projectsV2(first: 20) {
#         nodes {
#           id
#           title
#         }
#       }
#     }
#   }'
