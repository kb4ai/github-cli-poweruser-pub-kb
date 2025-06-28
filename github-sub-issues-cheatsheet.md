
  🎯 Quick Commands to Attach Sub-Issues

  Primary Method (Bash Script):

  # Attach existing issue #456 as sub-issue to parent #123
  ./github-sub-issues-crud.sh create-sub-issue --repo gwwtests/testxxxyyzzzzz --parent
  123 --child 456

  # With safety preview first
  ./github-sub-issues-crud.sh --dry-run create-sub-issue --repo gwwtests/testxxxyyzzzzz
  --parent 123 --child 456

  Alternative Method (Python):

  # Same operation using Python script
  python3 github_sub_issues.py create-sub-issue gwwtests/testxxxyyzzzzz 123 456

  Direct GraphQL (Advanced):

  # First get GraphQL IDs, then attach
  gh api graphql -f query='mutation($issueId: ID!, $subIssueId: ID!) {
    addSubIssue(input: {issueId: $issueId, subIssueId: $subIssueId}) {
      issue { title number }
      subIssue { title number }
    }
  }' -f issueId="PARENT_ID" -f subIssueId="CHILD_ID"

  🛡️ Safety Commands:

  # Check before attachment
  ./github-sub-issues-query.sh get-issue-info gwwtests/testxxxyyzzzzz 123
  ./github-sub-issues-query.sh get-parent gwwtests/testxxxyyzzzzz 456

  # Verify relationship after
  ./github-sub-issues-query.sh show-hierarchy gwwtests/testxxxyyzzzzz 123

  🔄 Management Commands:

  # Remove sub-issue relationship
  ./github-sub-issues-crud.sh remove-sub-issue --repo gwwtests/testxxxyyzzzzz --parent
  123 --child 456

  # Move to different parent
  ./github-sub-issues-crud.sh move-sub-issue --repo gwwtests/testxxxyyzzzzz --from 123
  --to 789 --child 456

  All scripts are located in your repository and ready to use! The commands provide full
  CRUD operations with safety checks and comprehensive error handling. 🚀


