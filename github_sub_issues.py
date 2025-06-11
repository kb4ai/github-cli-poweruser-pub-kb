#!/usr/bin/env python3
"""
GitHub Sub-Issues Management Tool

A Python script for managing GitHub sub-issues using the GitHub CLI and GraphQL API.
Provides both query and CRUD operations for sub-issue relationships.

Requirements:
    - GitHub CLI (gh) installed and authenticated
    - Python 3.6+
    - requests library (optional, uses gh cli instead)

Usage:
    python3 github_sub_issues.py [command] [options]

Examples:
    python3 github_sub_issues.py list-sub-issues owner/repo 1
    python3 github_sub_issues.py create-sub-issue owner/repo 1 2
    python3 github_sub_issues.py show-hierarchy owner/repo 1
"""

import argparse
import json
import subprocess
import sys
from typing import Dict, List, Optional, Tuple


class GitHubSubIssues:
    """GitHub Sub-Issues management class."""
    
    def __init__(self, verbose: bool = False, dry_run: bool = False):
        self.verbose = verbose
        self.dry_run = dry_run
        self._check_prerequisites()
    
    def _check_prerequisites(self):
        """Check if GitHub CLI is available and authenticated."""
        try:
            result = subprocess.run(['gh', 'auth', 'status'], 
                                  capture_output=True, text=True)
            if result.returncode != 0:
                raise Exception("GitHub CLI is not authenticated")
        except FileNotFoundError:
            raise Exception("GitHub CLI (gh) is not installed")
    
    def _log(self, message: str, level: str = "INFO"):
        """Log message with color coding."""
        colors = {
            "INFO": "\033[0;34m",
            "SUCCESS": "\033[0;32m",
            "WARNING": "\033[1;33m", 
            "ERROR": "\033[0;31m",
            "DRY_RUN": "\033[1;33m"
        }
        color = colors.get(level, "")
        reset = "\033[0m"
        
        if level != "INFO" or self.verbose:
            print(f"{color}[{level}]{reset} {message}", file=sys.stderr)
    
    def _run_graphql_query(self, query: str, variables: Dict = None) -> Dict:
        """Execute a GraphQL query using GitHub CLI."""
        cmd = ['gh', 'api', 'graphql', '--field', f'query={query}']
        
        if variables:
            for key, value in variables.items():
                cmd.extend(['--field', f'{key}={value}'])
        
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            return json.loads(result.stdout)
        except subprocess.CalledProcessError as e:
            self._log(f"GraphQL query failed: {e.stderr}", "ERROR")
            raise
        except json.JSONDecodeError as e:
            self._log(f"Failed to parse GraphQL response: {e}", "ERROR")
            raise
    
    def _get_issue_info(self, repo: str, issue_number: int) -> Tuple[str, str, str]:
        """Get issue GraphQL ID, title, and state."""
        owner, name = repo.split('/')
        
        query = '''
        query($owner: String!, $name: String!, $number: Int!) {
            repository(owner: $owner, name: $name) {
                issue(number: $number) {
                    id
                    title
                    state
                }
            }
        }'''
        
        variables = {
            'owner': owner,
            'name': name,
            'number': str(issue_number)
        }
        
        result = self._run_graphql_query(query, variables)
        issue_data = result['data']['repository']['issue']
        
        if not issue_data:
            raise Exception(f"Issue #{issue_number} not found in repository {repo}")
        
        return issue_data['id'], issue_data['title'], issue_data['state']
    
    def list_sub_issues(self, repo: str, parent_number: int, output_format: str = "table") -> None:
        """List all sub-issues of a parent issue."""
        self._log(f"Listing sub-issues for issue #{parent_number} in {repo}")
        
        owner, name = repo.split('/')
        
        query = '''
        query($owner: String!, $name: String!, $number: Int!) {
            repository(owner: $owner, name: $name) {
                issue(number: $number) {
                    title
                    number
                    state
                    subIssues(first: 100) {
                        totalCount
                        nodes {
                            title
                            number
                            state
                            url
                            assignees(first: 10) {
                                nodes {
                                    login
                                }
                            }
                            labels(first: 10) {
                                nodes {
                                    name
                                }
                            }
                            createdAt
                            updatedAt
                        }
                    }
                }
            }
        }'''
        
        variables = {
            'owner': owner,
            'name': name,
            'number': str(parent_number)
        }
        
        result = self._run_graphql_query(query, variables)
        issue_data = result['data']['repository']['issue']
        
        if not issue_data:
            raise Exception(f"Issue #{parent_number} not found in repository {repo}")
        
        sub_issues = issue_data['subIssues']
        total_count = sub_issues['totalCount']
        
        if total_count == 0:
            self._log(f"Issue #{parent_number} '{issue_data['title']}' has no sub-issues", "WARNING")
            return
        
        self._log(f"Found {total_count} sub-issues for issue #{parent_number} '{issue_data['title']}'", "SUCCESS")
        
        if output_format == "json":
            print(json.dumps(sub_issues, indent=2))
        elif output_format == "csv":
            print("Number,Title,State,URL,Assignees,Labels,Created,Updated")
            for sub_issue in sub_issues['nodes']:
                assignees = ';'.join([a['login'] for a in sub_issue['assignees']['nodes']])
                labels = ';'.join([l['name'] for l in sub_issue['labels']['nodes']])
                print(f"{sub_issue['number']},\"{sub_issue['title']}\",{sub_issue['state']},{sub_issue['url']},\"{assignees}\",\"{labels}\",{sub_issue['createdAt']},{sub_issue['updatedAt']}")
        else:  # table format
            print()
            print(f"{'NUM':<5} {'TITLE':<50} {'STATE':<10} {'ASSIGNEES':<20} {'LABELS':<30}")
            print(f"{'---':<5} {'-----':<50} {'-----':<10} {'---------':<20} {'------':<30}")
            
            for sub_issue in sub_issues['nodes']:
                title = sub_issue['title'][:47] + "..." if len(sub_issue['title']) > 50 else sub_issue['title']
                assignees = ','.join([a['login'] for a in sub_issue['assignees']['nodes']])[:17]
                if len(assignees) > 17:
                    assignees = assignees[:17] + "..."
                labels = ','.join([l['name'] for l in sub_issue['labels']['nodes']])[:27]
                if len(labels) > 27:
                    labels = labels[:27] + "..."
                
                print(f"{sub_issue['number']:<5} {title:<50} {sub_issue['state']:<10} {assignees:<20} {labels:<30}")
    
    def get_parent_issue(self, repo: str, issue_number: int, output_format: str = "table") -> None:
        """Get parent issue of a sub-issue."""
        self._log(f"Getting parent issue for issue #{issue_number} in {repo}")
        
        owner, name = repo.split('/')
        
        query = '''
        query($owner: String!, $name: String!, $number: Int!) {
            repository(owner: $owner, name: $name) {
                issue(number: $number) {
                    title
                    number
                    state
                    parent {
                        title
                        number
                        state
                        url
                        assignees(first: 10) {
                            nodes {
                                login
                            }
                        }
                        labels(first: 10) {
                            nodes {
                                name
                            }
                        }
                        createdAt
                        updatedAt
                    }
                }
            }
        }'''
        
        variables = {
            'owner': owner,
            'name': name,
            'number': str(issue_number)
        }
        
        result = self._run_graphql_query(query, variables)
        issue_data = result['data']['repository']['issue']
        
        if not issue_data:
            raise Exception(f"Issue #{issue_number} not found in repository {repo}")
        
        parent = issue_data['parent']
        
        if not parent:
            self._log(f"Issue #{issue_number} '{issue_data['title']}' has no parent issue", "WARNING")
            return
        
        self._log(f"Found parent issue for #{issue_number} '{issue_data['title']}'", "SUCCESS")
        
        if output_format == "json":
            print(json.dumps(parent, indent=2))
        elif output_format == "csv":
            assignees = ';'.join([a['login'] for a in parent['assignees']['nodes']])
            labels = ';'.join([l['name'] for l in parent['labels']['nodes']])
            print("Number,Title,State,URL,Assignees,Labels,Created,Updated")
            print(f"{parent['number']},\"{parent['title']}\",{parent['state']},{parent['url']},\"{assignees}\",\"{labels}\",{parent['createdAt']},{parent['updatedAt']}")
        else:  # table format
            print()
            print(f"{'PARENT #':<10} {'TITLE':<50} {'STATE':<10} {'ASSIGNEES':<20} {'LABELS':<30}")
            print(f"{'--------':<10} {'-----':<50} {'-----':<10} {'---------':<20} {'------':<30}")
            
            title = parent['title'][:47] + "..." if len(parent['title']) > 50 else parent['title']
            assignees = ','.join([a['login'] for a in parent['assignees']['nodes']])[:17]
            if len(assignees) > 17:
                assignees = assignees[:17] + "..."
            labels = ','.join([l['name'] for l in parent['labels']['nodes']])[:27]
            if len(labels) > 27:
                labels = labels[:27] + "..."
            
            print(f"{parent['number']:<10} {title:<50} {parent['state']:<10} {assignees:<20} {labels:<30}")
    
    def show_hierarchy(self, repo: str, issue_number: int, output_format: str = "tree") -> None:
        """Show hierarchical structure of issues."""
        self._log(f"Showing hierarchy for issue #{issue_number} in {repo}")
        
        # First check if this issue has a parent (it's a sub-issue)
        owner, name = repo.split('/')
        
        parent_query = '''
        query($owner: String!, $name: String!, $number: Int!) {
            repository(owner: $owner, name: $name) {
                issue(number: $number) {
                    title
                    number
                    parent {
                        title
                        number
                    }
                }
            }
        }'''
        
        variables = {
            'owner': owner,
            'name': name,
            'number': str(issue_number)
        }
        
        result = self._run_graphql_query(parent_query, variables)
        issue_data = result['data']['repository']['issue']
        
        if issue_data['parent']:
            # This is a sub-issue, show from parent
            parent_num = issue_data['parent']['number']
            self._log(f"Issue #{issue_number} is a sub-issue. Showing hierarchy from parent #{parent_num}")
            issue_number = parent_num
        
        # Now show the full hierarchy
        hierarchy_query = '''
        query($owner: String!, $name: String!, $number: Int!) {
            repository(owner: $owner, name: $name) {
                issue(number: $number) {
                    title
                    number
                    state
                    subIssues(first: 100) {
                        totalCount
                        nodes {
                            title
                            number
                            state
                            subIssues(first: 100) {
                                totalCount
                                nodes {
                                    title
                                    number
                                    state
                                }
                            }
                        }
                    }
                }
            }
        }'''
        
        variables['number'] = str(issue_number)
        result = self._run_graphql_query(hierarchy_query, variables)
        issue_data = result['data']['repository']['issue']
        
        if output_format == "json":
            print(json.dumps(issue_data, indent=2))
            return
        
        print()
        print("ISSUE HIERARCHY:")
        print("==================")
        
        # Show parent issue
        parent_title = issue_data['title']
        parent_state = issue_data['state']
        print(f"├── #{issue_number}: {parent_title} [{parent_state}]")
        
        # Show sub-issues
        total_subs = issue_data['subIssues']['totalCount']
        
        if total_subs == 0:
            print("    └── (no sub-issues)")
        else:
            for sub_issue in issue_data['subIssues']['nodes']:
                sub_count = sub_issue['subIssues']['totalCount']
                if sub_count == 0:
                    print(f"    ├── #{sub_issue['number']}: {sub_issue['title']} [{sub_issue['state']}]")
                else:
                    print(f"    ├── #{sub_issue['number']}: {sub_issue['title']} [{sub_issue['state']}] ({sub_count} sub-issues)")
    
    def create_sub_issue(self, repo: str, parent_number: int, child_number: int) -> None:
        """Create a parent-child relationship between two existing issues."""
        self._log(f"Creating sub-issue relationship: #{parent_number} -> #{child_number} in {repo}")
        
        # Get GraphQL IDs
        parent_id, parent_title, parent_state = self._get_issue_info(repo, parent_number)
        child_id, child_title, child_state = self._get_issue_info(repo, child_number)
        
        print("Creating parent-child relationship:")
        print(f"  Parent: #{parent_number} '{parent_title}' [{parent_state}]")
        print(f"  Child:  #{child_number} '{child_title}' [{child_state}]")
        print()
        
        if self.dry_run:
            self._log(f"Would add issue #{child_number} as sub-issue of #{parent_number}", "DRY_RUN")
            return
        
        mutation = '''
        mutation($issueId: ID!, $subIssueId: ID!) {
            addSubIssue(input: {
                issueId: $issueId
                subIssueId: $subIssueId
            }) {
                issue {
                    title
                    number
                }
                subIssue {
                    title
                    number
                }
            }
        }'''
        
        variables = {
            'issueId': parent_id,
            'subIssueId': child_id
        }
        
        result = self._run_graphql_query(mutation, variables)
        mutation_data = result['data']['addSubIssue']
        
        self._log("Successfully added sub-issue relationship", "SUCCESS")
        print(f"  Parent: #{mutation_data['issue']['number']} '{mutation_data['issue']['title']}'")
        print(f"  Child:  #{mutation_data['subIssue']['number']} '{mutation_data['subIssue']['title']}'")
    
    def remove_sub_issue(self, repo: str, parent_number: int, child_number: int) -> None:
        """Remove a parent-child relationship."""
        self._log(f"Removing sub-issue relationship: #{parent_number} -> #{child_number} in {repo}")
        
        # Get GraphQL IDs
        parent_id, parent_title, parent_state = self._get_issue_info(repo, parent_number)
        child_id, child_title, child_state = self._get_issue_info(repo, child_number)
        
        print("Removing parent-child relationship:")
        print(f"  Parent: #{parent_number} '{parent_title}' [{parent_state}]")
        print(f"  Child:  #{child_number} '{child_title}' [{child_state}] (will become standalone)")
        print()
        
        if self.dry_run:
            self._log(f"Would remove sub-issue relationship between #{parent_number} and #{child_number}", "DRY_RUN")
            return
        
        mutation = '''
        mutation($issueId: ID!, $subIssueId: ID!) {
            removeSubIssue(input: {
                issueId: $issueId
                subIssueId: $subIssueId
            }) {
                issue {
                    title
                    number
                }
                subIssue {
                    title
                    number
                }
            }
        }'''
        
        variables = {
            'issueId': parent_id,
            'subIssueId': child_id
        }
        
        result = self._run_graphql_query(mutation, variables)
        mutation_data = result['data']['removeSubIssue']
        
        self._log("Successfully removed sub-issue relationship", "SUCCESS")
        print(f"  Parent: #{mutation_data['issue']['number']} '{mutation_data['issue']['title']}'")
        print(f"  Child:  #{mutation_data['subIssue']['number']} '{mutation_data['subIssue']['title']}' (now standalone)")
    
    def create_issue_as_sub(self, repo: str, parent_number: int, title: str, body: str = "") -> None:
        """Create a new issue and add it as a sub-issue."""
        self._log(f"Creating new issue as sub-issue of #{parent_number} in {repo}")
        
        # Get parent info
        parent_id, parent_title, parent_state = self._get_issue_info(repo, parent_number)
        
        print("Creating new issue as sub-issue:")
        print(f"  Parent: #{parent_number} '{parent_title}' [{parent_state}]")
        print(f"  Title:  {title}")
        if body:
            print(f"  Body:   {body[:50]}...")
        print()
        
        if self.dry_run:
            self._log(f"Would create new issue '{title}' as sub-issue of #{parent_number}", "DRY_RUN")
            return
        
        # Create the issue using gh CLI
        cmd = ['gh', 'issue', 'create', '--repo', repo, '--title', title]
        if body:
            cmd.extend(['--body', body])
        
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            issue_url = result.stdout.strip()
            new_issue_number = int(issue_url.split('/')[-1])
            self._log(f"Created issue #{new_issue_number}", "SUCCESS")
        except subprocess.CalledProcessError as e:
            self._log(f"Failed to create issue: {e.stderr}", "ERROR")
            raise
        
        # Get the new issue's GraphQL ID
        child_id, child_title, child_state = self._get_issue_info(repo, new_issue_number)
        
        # Add as sub-issue
        self._log("Adding as sub-issue...")
        mutation = '''
        mutation($issueId: ID!, $subIssueId: ID!) {
            addSubIssue(input: {
                issueId: $issueId
                subIssueId: $subIssueId
            }) {
                issue {
                    title
                    number
                }
                subIssue {
                    title
                    number
                }
            }
        }'''
        
        variables = {
            'issueId': parent_id,
            'subIssueId': child_id
        }
        
        mutation_result = self._run_graphql_query(mutation, variables)
        
        self._log("Successfully created issue as sub-issue", "SUCCESS")
        print(f"  Parent: #{parent_number} '{parent_title}'")
        print(f"  Child:  #{new_issue_number} '{title}'")
        print(f"  URL:    {issue_url}")


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="GitHub Sub-Issues Management Tool",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s list-sub-issues owner/repo 1
  %(prog)s get-parent owner/repo 2
  %(prog)s show-hierarchy owner/repo 1
  %(prog)s create-sub-issue owner/repo 1 2
  %(prog)s remove-sub-issue owner/repo 1 2
  %(prog)s create-issue-as-sub owner/repo 1 "New Task" "Task description"
        """
    )
    
    parser.add_argument('-v', '--verbose', action='store_true', 
                       help='Enable verbose output')
    parser.add_argument('-n', '--dry-run', action='store_true',
                       help='Show what would be done without making changes')
    parser.add_argument('-f', '--format', choices=['table', 'json', 'csv'], 
                       default='table', help='Output format (default: table)')
    
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # List sub-issues command
    list_parser = subparsers.add_parser('list-sub-issues', 
                                       help='List all sub-issues of a parent issue')
    list_parser.add_argument('repo', help='Repository in format owner/repo')
    list_parser.add_argument('parent_number', type=int, help='Parent issue number')
    
    # Get parent command
    parent_parser = subparsers.add_parser('get-parent',
                                         help='Get parent issue of a sub-issue')
    parent_parser.add_argument('repo', help='Repository in format owner/repo')
    parent_parser.add_argument('issue_number', type=int, help='Issue number')
    
    # Show hierarchy command
    hierarchy_parser = subparsers.add_parser('show-hierarchy',
                                            help='Display hierarchical structure')
    hierarchy_parser.add_argument('repo', help='Repository in format owner/repo')
    hierarchy_parser.add_argument('issue_number', type=int, help='Issue number')
    
    # Create sub-issue command
    create_parser = subparsers.add_parser('create-sub-issue',
                                         help='Create parent-child relationship')
    create_parser.add_argument('repo', help='Repository in format owner/repo')
    create_parser.add_argument('parent_number', type=int, help='Parent issue number')
    create_parser.add_argument('child_number', type=int, help='Child issue number')
    
    # Remove sub-issue command
    remove_parser = subparsers.add_parser('remove-sub-issue',
                                         help='Remove parent-child relationship')
    remove_parser.add_argument('repo', help='Repository in format owner/repo')
    remove_parser.add_argument('parent_number', type=int, help='Parent issue number')
    remove_parser.add_argument('child_number', type=int, help='Child issue number')
    
    # Create issue as sub-issue command
    create_as_sub_parser = subparsers.add_parser('create-issue-as-sub',
                                                help='Create new issue as sub-issue')
    create_as_sub_parser.add_argument('repo', help='Repository in format owner/repo')
    create_as_sub_parser.add_argument('parent_number', type=int, help='Parent issue number')
    create_as_sub_parser.add_argument('title', help='Issue title')
    create_as_sub_parser.add_argument('body', nargs='?', default='', help='Issue body (optional)')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return 1
    
    try:
        github = GitHubSubIssues(verbose=args.verbose, dry_run=args.dry_run)
        
        if args.command == 'list-sub-issues':
            github.list_sub_issues(args.repo, args.parent_number, args.format)
        elif args.command == 'get-parent':
            github.get_parent_issue(args.repo, args.issue_number, args.format)
        elif args.command == 'show-hierarchy':
            github.show_hierarchy(args.repo, args.issue_number, args.format)
        elif args.command == 'create-sub-issue':
            github.create_sub_issue(args.repo, args.parent_number, args.child_number)
        elif args.command == 'remove-sub-issue':
            github.remove_sub_issue(args.repo, args.parent_number, args.child_number)
        elif args.command == 'create-issue-as-sub':
            github.create_issue_as_sub(args.repo, args.parent_number, args.title, args.body)
        
        return 0
        
    except Exception as e:
        print(f"\033[0;31m[ERROR]\033[0m {e}", file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())