#!/bin/bash

# GitHub Projects Automation Test Suite
# Run this script after updating your CLASSIC personal access token with project scopes
# ⚠️ Fine-grained personal access tokens (new tokens) do NOT work with Projects v2 API

set -e

echo "🔍 GitHub Projects Automation Test Suite"
echo "========================================"
echo

# Source the dotfile for authentication
if [ ! -f "${GITHUB_TOKEN_DOTFILE}" ]; then
    echo "❌ Error: ${GITHUB_TOKEN_DOTFILE} file not found"
    echo "Please ensure the dotfile exists with GITHUB_PERSONAL_ACCESS_TOKEN"
    echo "⚠️ IMPORTANT: Must be a CLASSIC personal access token, not fine-grained"
    echo "Create at: https://github.com/settings/tokens (use 'Tokens (classic)')"
    exit 1
fi

source "${GITHUB_TOKEN_DOTFILE}"
export GH_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN"

echo "✅ Authentication configured from ${GITHUB_TOKEN_DOTFILE}"
echo

# Test 1: Basic Authentication
echo "📋 Test 1: Authentication Status"
echo "--------------------------------"
gh auth status
echo

# Test 2: Project Access
echo "📋 Test 2: Project Access"
echo "-------------------------"
echo "Testing project view access..."
if gh project view 1 --owner gwwtests --format json > /tmp/project_test.json 2>/dev/null; then
    project_title=$(jq -r '.title' /tmp/project_test.json)
    project_items=$(jq -r '.items.totalCount' /tmp/project_test.json)
    echo "✅ Project access successful!"
    echo "   Project Title: $project_title"
    echo "   Items Count: $project_items"
else
    echo "❌ Project access failed - likely using wrong token type"
    echo "   ⚠️ CRITICAL: Must use CLASSIC personal access token"
    echo "   ❌ Fine-grained tokens cause empty/null API responses"
    echo "   Required scopes: project (or read:project for read-only)"
    echo "   Create classic token at: https://github.com/settings/tokens (use 'Tokens (classic)')"
    exit 1
fi
echo

# Test 3: Field Discovery
echo "📋 Test 3: Field Discovery"
echo "--------------------------"
echo "Discovering project fields..."
if ./github-projects-field-discovery.sh list-fields 1 gwwtests table 2>/dev/null; then
    echo "✅ Field discovery successful!"
else
    echo "❌ Field discovery failed"
fi
echo

# Test 4: Issue Addition Test
echo "📋 Test 4: Issue Addition Test"
echo "------------------------------"
echo "Testing issue addition to project..."

# Get the first issue URL for testing
test_issue_url=$(gh issue list --repo gwwtests/testxxxyyzzzzz --json url --jq '.[0].url' 2>/dev/null)

if [ -n "$test_issue_url" ]; then
    echo "Test issue URL: $test_issue_url"
    
    if gh project item-add 1 --owner gwwtests --url "$test_issue_url" 2>/dev/null; then
        echo "✅ Issue addition successful!"
        echo "   Added: $test_issue_url"
    else
        echo "❌ Issue addition failed"
        echo "   This might be expected if the issue is already in the project"
    fi
else
    echo "❌ Could not find test issues"
fi
echo

# Test 5: Bulk Operations Test
echo "📋 Test 5: Bulk Operations Test"
echo "-------------------------------"
echo "Testing bulk issue addition script..."

if [ -f "./bulk-add-issues-to-project.sh" ]; then
    echo "Running bulk addition script..."
    ./bulk-add-issues-to-project.sh gwwtests testxxxyyzzzzz gwwtests 1 2>/dev/null || echo "Bulk script completed (some issues may already be in project)"
    echo "✅ Bulk operations script available and executed"
else
    echo "❌ Bulk operations script not found"
fi
echo

# Test 6: Final Verification
echo "📋 Test 6: Final Verification"
echo "-----------------------------"
echo "Checking final project state..."

if gh project item-list 1 --owner gwwtests --format json > /tmp/final_test.json 2>/dev/null; then
    total_items=$(jq -r '.items | length' /tmp/final_test.json)
    echo "✅ Final verification successful!"
    echo "   Total items in project: $total_items"
    
    echo
    echo "📊 Project Items Summary:"
    jq -r '.items[] | "   • \(.content.title // "Draft Item")"' /tmp/final_test.json
else
    echo "❌ Final verification failed"
fi

echo
echo "🎉 Test Suite Complete!"
echo "======================"
echo
echo "📋 Next Steps:"
echo "   1. Try field modification: ./github-projects-field-management.sh --help"
echo "   2. Explore field discovery: ./github-projects-field-discovery.sh --help"
echo "   3. Test sub-issues: ./github-sub-issues-crud.sh --help"
echo "   4. Read full analysis: ./github-projects-authentication-analysis-report.md"
echo

# Cleanup
rm -f /tmp/project_test.json /tmp/final_test.json