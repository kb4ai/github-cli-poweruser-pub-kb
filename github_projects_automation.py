#!/usr/bin/env python3
"""
GitHub Projects Automation - Python Implementation
 
This script provides comprehensive GitHub Projects automation capabilities in Python.
It includes all functionality from the bash scripts plus additional features like
configuration management, detailed logging, and enhanced error handling.

Usage Examples:
    python3 github_projects_automation.py list-items 1 ExampleOrg
    python3 github_projects_automation.py add-issue 1 ExampleOrg https://github.com/owner/repo/issues/1
    python3 github_projects_automation.py set-field 1 ExampleOrg ITEM_ID "Status" "Done"
    python3 github_projects_automation.py export-schema 1 ExampleOrg --format json --output schema.json

Requirements:
- Python 3.7+
- requests library (pip install requests)
- GitHub CLI (gh) installed and authenticated
- project scope authorization
"""

import sys
import os
import json
import csv
import re
import time
import argparse
import logging
import subprocess
from typing import Dict, List, Optional, Any, Union
from datetime import datetime
from dataclasses import dataclass
from pathlib import Path

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/tmp/github_projects_automation.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Constants
VERSION = "1.0.0"
MAX_RETRIES = 3
RETRY_DELAY = 2
GRAPHQL_ENDPOINT = "https://api.github.com/graphql"

@dataclass
class ProjectField:
    """Represents a GitHub Project field"""
    id: str
    name: str
    data_type: str
    options: List[Dict[str, str]] = None
    iterations: List[Dict[str, str]] = None
    
@dataclass
class ProjectItem:
    """Represents a GitHub Project item"""
    id: str
    type: str
    title: str
    url: str = None
    number: int = None
    state: str = None
    assignees: List[str] = None
    field_values: Dict[str, Any] = None

class GitHubProjectsAPI:
    """GitHub Projects API client"""
    
    def __init__(self, token: str = None):
        """Initialize the API client"""
        self.token = token or self._get_github_token()
        self.session = None
        
    def _get_github_token(self) -> str:
        """Get GitHub token from gh CLI"""
        try:
            result = subprocess.run(
                ['gh', 'auth', 'token'],
                capture_output=True,
                text=True,
                check=True
            )
            return result.stdout.strip()
        except subprocess.CalledProcessError as e:
            raise Exception(f"Failed to get GitHub token from gh CLI: {e}")
    
    def _execute_gh_command(self, command: List[str]) -> Dict[str, Any]:
        """Execute gh CLI command and return JSON result"""
        try:
            result = subprocess.run(
                command,
                capture_output=True,
                text=True,
                check=True
            )
            return json.loads(result.stdout) if result.stdout else {}
        except subprocess.CalledProcessError as e:
            logger.error(f"Command failed: {' '.join(command)}")
            logger.error(f"Error: {e.stderr}")
            raise Exception(f"GitHub CLI command failed: {e}")
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse JSON response: {result.stdout}")
            raise Exception(f"Invalid JSON response: {e}")
    
    def _execute_graphql_query(self, query: str, variables: Dict[str, Any] = None) -> Dict[str, Any]:
        """Execute GraphQL query using gh CLI"""
        command = ['gh', 'api', 'graphql', '-f', f'query={query}']
        
        if variables:
            for key, value in variables.items():
                command.extend(['-F', f'{key}={value}'])
        
        return self._execute_gh_command(command)
    
    def get_project_id(self, project_num: int, owner: str) -> str:
        """Get project ID from project number and owner"""
        if '/' in owner:
            # User project
            username = owner.split('/')[0]
            query = f'''
            query {{
                user(login: "{username}") {{
                    projectV2(number: {project_num}) {{
                        id
                    }}
                }}
            }}
            '''
            result = self._execute_graphql_query(query)
            project_id = result.get('data', {}).get('user', {}).get('projectV2', {}).get('id')
        else:
            # Organization project
            query = f'''
            query {{
                organization(login: "{owner}") {{
                    projectV2(number: {project_num}) {{
                        id
                    }}
                }}
            }}
            '''
            result = self._execute_graphql_query(query)
            project_id = result.get('data', {}).get('organization', {}).get('projectV2', {}).get('id')
        
        if not project_id:
            raise Exception(f"Project {project_num} not found for owner {owner}")
        
        return project_id
    
    def get_project_fields(self, project_num: int, owner: str) -> List[ProjectField]:
        """Get all fields for a project"""
        project_id = self.get_project_id(project_num, owner)
        
        query = '''
        query($projectId: ID!) {
            node(id: $projectId) {
                ... on ProjectV2 {
                    title
                    fields(first: 50) {
                        nodes {
                            ... on ProjectV2Field {
                                id
                                name
                                dataType
                            }
                            ... on ProjectV2SingleSelectField {
                                id
                                name
                                dataType
                                options {
                                    id
                                    name
                                    color
                                    description
                                }
                            }
                            ... on ProjectV2IterationField {
                                id
                                name
                                dataType
                                configuration {
                                    iterations {
                                        id
                                        title
                                        startDate
                                        duration
                                    }
                                    completedIterations {
                                        id
                                        title
                                        startDate
                                        duration
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        '''
        
        result = self._execute_graphql_query(query, {'projectId': project_id})
        fields_data = result.get('data', {}).get('node', {}).get('fields', {}).get('nodes', [])
        
        fields = []
        for field_data in fields_data:
            field = ProjectField(
                id=field_data.get('id'),
                name=field_data.get('name'),
                data_type=field_data.get('dataType'),
                options=field_data.get('options', []),
                iterations=(
                    field_data.get('configuration', {}).get('iterations', []) +
                    field_data.get('configuration', {}).get('completedIterations', [])
                ) if field_data.get('configuration') else []
            )
            fields.append(field)
        
        return fields
    
    def get_project_items(self, project_num: int, owner: str) -> List[ProjectItem]:
        """Get all items in a project"""
        project_id = self.get_project_id(project_num, owner)
        
        query = '''
        query($projectId: ID!) {
            node(id: $projectId) {
                ... on ProjectV2 {
                    title
                    items(first: 100) {
                        nodes {
                            id
                            type
                            content {
                                ... on Issue {
                                    title
                                    number
                                    url
                                    state
                                    assignees(first: 5) {
                                        nodes {
                                            login
                                        }
                                    }
                                    labels(first: 10) {
                                        nodes {
                                            name
                                        }
                                    }
                                }
                                ... on PullRequest {
                                    title
                                    number
                                    url
                                    state
                                    assignees(first: 5) {
                                        nodes {
                                            login
                                        }
                                    }
                                }
                                ... on DraftIssue {
                                    title
                                }
                            }
                            fieldValues(first: 20) {
                                nodes {
                                    ... on ProjectV2ItemFieldTextValue {
                                        field {
                                            ... on ProjectV2Field {
                                                name
                                            }
                                        }
                                        text
                                    }
                                    ... on ProjectV2ItemFieldSingleSelectValue {
                                        field {
                                            ... on ProjectV2SingleSelectField {
                                                name
                                            }
                                        }
                                        name
                                        optionId
                                    }
                                    ... on ProjectV2ItemFieldDateValue {
                                        field {
                                            ... on ProjectV2Field {
                                                name
                                            }
                                        }
                                        date
                                    }
                                    ... on ProjectV2ItemFieldNumberValue {
                                        field {
                                            ... on ProjectV2Field {
                                                name
                                            }
                                        }
                                        number
                                    }
                                    ... on ProjectV2ItemFieldIterationValue {
                                        field {
                                            ... on ProjectV2IterationField {
                                                name
                                            }
                                        }
                                        title
                                        iterationId
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        '''
        
        result = self._execute_graphql_query(query, {'projectId': project_id})
        items_data = result.get('data', {}).get('node', {}).get('items', {}).get('nodes', [])
        
        items = []
        for item_data in items_data:
            content = item_data.get('content', {})
            
            # Parse field values
            field_values = {}
            for field_value in item_data.get('fieldValues', {}).get('nodes', []):
                field_name = field_value.get('field', {}).get('name')
                if field_name:
                    if 'text' in field_value:
                        field_values[field_name] = field_value['text']
                    elif 'name' in field_value:
                        field_values[field_name] = field_value['name']
                    elif 'date' in field_value:
                        field_values[field_name] = field_value['date']
                    elif 'number' in field_value:
                        field_values[field_name] = field_value['number']
                    elif 'title' in field_value:
                        field_values[field_name] = field_value['title']
            
            item = ProjectItem(
                id=item_data.get('id'),
                type=item_data.get('type'),
                title=content.get('title', 'Unknown'),
                url=content.get('url'),
                number=content.get('number'),
                state=content.get('state'),
                assignees=[assignee.get('login') for assignee in content.get('assignees', {}).get('nodes', [])],
                field_values=field_values
            )
            items.append(item)
        
        return items
    
    def get_content_id(self, url: str) -> str:
        """Get content ID from GitHub URL"""
        pattern = r'github\.com/([^/]+)/([^/]+)/(issues|pull)/(\d+)'
        match = re.match(pattern, url.replace('https://', ''))
        
        if not match:
            raise Exception(f"Invalid GitHub URL format: {url}")
        
        owner, repo, content_type, number = match.groups()
        
        if content_type == 'issues':
            query = f'''
            query {{
                repository(owner: "{owner}", name: "{repo}") {{
                    issue(number: {number}) {{
                        id
                    }}
                }}
            }}
            '''
            result = self._execute_graphql_query(query)
            content_id = result.get('data', {}).get('repository', {}).get('issue', {}).get('id')
        else:  # pull request
            query = f'''
            query {{
                repository(owner: "{owner}", name: "{repo}") {{
                    pullRequest(number: {number}) {{
                        id
                    }}
                }}
            }}
            '''
            result = self._execute_graphql_query(query)
            content_id = result.get('data', {}).get('repository', {}).get('pullRequest', {}).get('id')
        
        if not content_id:
            raise Exception(f"Content not found for URL: {url}")
        
        return content_id
    
    def add_item_to_project(self, project_num: int, owner: str, url: str) -> str:
        """Add issue/PR to project"""
        project_id = self.get_project_id(project_num, owner)
        content_id = self.get_content_id(url)
        
        mutation = '''
        mutation($projectId: ID!, $contentId: ID!) {
            addProjectV2ItemById(input: {
                projectId: $projectId
                contentId: $contentId
            }) {
                item {
                    id
                    content {
                        ... on Issue {
                            title
                        }
                        ... on PullRequest {
                            title
                        }
                    }
                }
            }
        }
        '''
        
        result = self._execute_graphql_query(mutation, {
            'projectId': project_id,
            'contentId': content_id
        })
        
        item_data = result.get('data', {}).get('addProjectV2ItemById', {}).get('item')
        if not item_data:
            errors = result.get('errors', [])
            if any('already exists' in str(error).lower() for error in errors):
                logger.warning("Item already exists in project")
                return None
            raise Exception(f"Failed to add item to project: {errors}")
        
        return item_data.get('id')
    
    def remove_item_from_project(self, project_num: int, owner: str, item_id: str) -> str:
        """Remove item from project"""
        project_id = self.get_project_id(project_num, owner)
        
        mutation = '''
        mutation($projectId: ID!, $itemId: ID!) {
            deleteProjectV2Item(input: {
                projectId: $projectId
                itemId: $itemId
            }) {
                deletedItemId
            }
        }
        '''
        
        result = self._execute_graphql_query(mutation, {
            'projectId': project_id,
            'itemId': item_id
        })
        
        deleted_id = result.get('data', {}).get('deleteProjectV2Item', {}).get('deletedItemId')
        if not deleted_id:
            errors = result.get('errors', [])
            raise Exception(f"Failed to remove item from project: {errors}")
        
        return deleted_id
    
    def update_field_value(self, project_num: int, owner: str, item_id: str, field_name: str, value: str) -> bool:
        """Update field value for an item"""
        project_id = self.get_project_id(project_num, owner)
        fields = self.get_project_fields(project_num, owner)
        
        # Find the field
        field = next((f for f in fields if f.name == field_name), None)
        if not field:
            raise Exception(f"Field '{field_name}' not found in project")
        
        mutation_vars = {
            'projectId': project_id,
            'itemId': item_id,
            'fieldId': field.id
        }
        
        # Build mutation based on field type
        if field.data_type == 'TEXT':
            mutation = '''
            mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $value: String!) {
                updateProjectV2ItemFieldValue(input: {
                    projectId: $projectId
                    itemId: $itemId
                    fieldId: $fieldId
                    value: { text: $value }
                }) {
                    projectV2Item { id }
                }
            }
            '''
            mutation_vars['value'] = value
        
        elif field.data_type == 'NUMBER':
            try:
                numeric_value = float(value)
            except ValueError:
                raise Exception(f"Invalid number format: {value}")
            
            mutation = '''
            mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $value: Float!) {
                updateProjectV2ItemFieldValue(input: {
                    projectId: $projectId
                    itemId: $itemId
                    fieldId: $fieldId
                    value: { number: $value }
                }) {
                    projectV2Item { id }
                }
            }
            '''
            mutation_vars['value'] = numeric_value
        
        elif field.data_type == 'DATE':
            if not re.match(r'^\d{4}-\d{2}-\d{2}$', value):
                raise Exception(f"Invalid date format: {value} (expected YYYY-MM-DD)")
            
            mutation = '''
            mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $value: Date!) {
                updateProjectV2ItemFieldValue(input: {
                    projectId: $projectId
                    itemId: $itemId
                    fieldId: $fieldId
                    value: { date: $value }
                }) {
                    projectV2Item { id }
                }
            }
            '''
            mutation_vars['value'] = value
        
        elif field.data_type == 'SINGLE_SELECT':
            # Find option ID by name
            option = next((opt for opt in field.options if opt['name'] == value), None)
            if not option:
                raise Exception(f"Option '{value}' not found in field '{field_name}'")
            
            mutation = '''
            mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
                updateProjectV2ItemFieldValue(input: {
                    projectId: $projectId
                    itemId: $itemId
                    fieldId: $fieldId
                    value: { singleSelectOptionId: $optionId }
                }) {
                    projectV2Item { id }
                }
            }
            '''
            mutation_vars['optionId'] = option['id']
        
        elif field.data_type == 'ITERATION':
            # Find iteration ID by title
            iteration = next((it for it in field.iterations if it['title'] == value), None)
            if not iteration:
                raise Exception(f"Iteration '{value}' not found in field '{field_name}'")
            
            mutation = '''
            mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $iterationId: String!) {
                updateProjectV2ItemFieldValue(input: {
                    projectId: $projectId
                    itemId: $itemId
                    fieldId: $fieldId
                    value: { iterationId: $iterationId }
                }) {
                    projectV2Item { id }
                }
            }
            '''
            mutation_vars['iterationId'] = iteration['id']
        
        else:
            raise Exception(f"Unsupported field type: {field.data_type}")
        
        result = self._execute_graphql_query(mutation, mutation_vars)
        
        updated_item = result.get('data', {}).get('updateProjectV2ItemFieldValue', {}).get('projectV2Item')
        if not updated_item:
            errors = result.get('errors', [])
            raise Exception(f"Failed to update field: {errors}")
        
        return True

class GitHubProjectsAutomation:
    """Main automation class"""
    
    def __init__(self, verbose: bool = False):
        """Initialize automation"""
        self.api = GitHubProjectsAPI()
        self.verbose = verbose
        
        if verbose:
            logging.getLogger().setLevel(logging.DEBUG)
    
    def list_items(self, project_num: int, owner: str, format_type: str = 'table', output_file: str = None):
        """List all items in project"""
        logger.info(f"Listing items in project {project_num} (owner: {owner})")
        
        items = self.api.get_project_items(project_num, owner)
        
        if format_type == 'json':
            output = json.dumps([{
                'id': item.id,
                'type': item.type,
                'title': item.title,
                'url': item.url,
                'number': item.number,
                'state': item.state,
                'assignees': item.assignees,
                'field_values': item.field_values
            } for item in items], indent=2)
        
        elif format_type == 'csv':
            output_lines = ['Item ID,Type,Title,Number,URL,State,Assignees,Custom Fields']
            for item in items:
                assignees = ';'.join(item.assignees or [])
                fields = ';'.join([f"{k}:{v}" for k, v in (item.field_values or {}).items()])
                output_lines.append(f'"{item.id}","{item.type}","{item.title}","{item.number}","{item.url}","{item.state}","{assignees}","{fields}"')
            output = '\n'.join(output_lines)
        
        else:  # table format
            print(f"\n🔹 Project Items ({len(items)} total)")
            print("=" * 120)
            print(f"{'ID':<32} {'TYPE':<12} {'TITLE':<50} {'#':<6} {'STATE':<12} {'ASSIGNEES':<20}")
            print("-" * 120)
            
            for item in items:
                title = item.title[:47] + "..." if len(item.title) > 50 else item.title
                assignees = ','.join(item.assignees[:2] or [])
                if len(item.assignees or []) > 2:
                    assignees += "..."
                    
                print(f"{item.id:<32} {item.type:<12} {title:<50} {item.number or 'N/A':<6} {item.state or 'N/A':<12} {assignees:<20}")
            
            print(f"\n✅ Listed {len(items)} items")
            return
        
        if output_file:
            Path(output_file).write_text(output)
            print(f"✅ Output saved to {output_file}")
        else:
            print(output)
    
    def list_fields(self, project_num: int, owner: str, format_type: str = 'table', output_file: str = None):
        """List all fields in project"""
        logger.info(f"Listing fields in project {project_num} (owner: {owner})")
        
        fields = self.api.get_project_fields(project_num, owner)
        
        if format_type == 'json':
            output = json.dumps([{
                'id': field.id,
                'name': field.name,
                'data_type': field.data_type,
                'options': field.options,
                'iterations': field.iterations
            } for field in fields], indent=2)
        
        elif format_type == 'csv':
            output_lines = ['Field ID,Field Name,Data Type,Options/Iterations']
            for field in fields:
                options = ';'.join([opt['name'] for opt in (field.options or [])])
                iterations = ';'.join([it['title'] for it in (field.iterations or [])])
                config = options or iterations or 'N/A'
                output_lines.append(f'"{field.id}","{field.name}","{field.data_type}","{config}"')
            output = '\n'.join(output_lines)
        
        else:  # table format
            print(f"\n🔹 Project Fields ({len(fields)} total)")
            print("=" * 100)
            print(f"{'ID':<32} {'NAME':<20} {'TYPE':<15} {'OPTIONS/ITERATIONS':<30}")
            print("-" * 100)
            
            for field in fields:
                options = ','.join([opt['name'] for opt in (field.options or [])])
                iterations = ','.join([it['title'] for it in (field.iterations or [])])
                config = options or iterations or 'N/A'
                config = config[:27] + "..." if len(config) > 30 else config
                
                print(f"{field.id:<32} {field.name:<20} {field.data_type:<15} {config:<30}")
            
            print(f"\n✅ Listed {len(fields)} fields")
            return
        
        if output_file:
            Path(output_file).write_text(output)
            print(f"✅ Output saved to {output_file}")
        else:
            print(output)
    
    def add_issue(self, project_num: int, owner: str, url: str):
        """Add issue/PR to project"""
        logger.info(f"Adding {url} to project {project_num}")
        
        try:
            item_id = self.api.add_item_to_project(project_num, owner, url)
            if item_id:
                print(f"✅ Added item to project (ID: {item_id})")
            else:
                print("⚠️ Item already exists in project")
        except Exception as e:
            print(f"❌ Failed to add item: {e}")
            sys.exit(1)
    
    def remove_item(self, project_num: int, owner: str, item_id: str):
        """Remove item from project"""
        logger.info(f"Removing item {item_id} from project {project_num}")
        
        try:
            deleted_id = self.api.remove_item_from_project(project_num, owner, item_id)
            print(f"✅ Removed item from project (ID: {deleted_id})")
        except Exception as e:
            print(f"❌ Failed to remove item: {e}")
            sys.exit(1)
    
    def set_field(self, project_num: int, owner: str, item_id: str, field_name: str, value: str, dry_run: bool = False):
        """Set field value for item"""
        logger.info(f"Setting field '{field_name}' to '{value}' for item {item_id}")
        
        if dry_run:
            print(f"🔍 DRY RUN: Would set field '{field_name}' to '{value}' for item {item_id}")
            return
        
        try:
            self.api.update_field_value(project_num, owner, item_id, field_name, value)
            print(f"✅ Updated field '{field_name}' to '{value}'")
        except Exception as e:
            print(f"❌ Failed to update field: {e}")
            sys.exit(1)
    
    def bulk_update(self, project_num: int, owner: str, csv_file: str, dry_run: bool = False):
        """Bulk update field values from CSV"""
        logger.info(f"Bulk updating from {csv_file}")
        
        if not Path(csv_file).exists():
            print(f"❌ File not found: {csv_file}")
            sys.exit(1)
        
        updated = 0
        failed = 0
        
        with open(csv_file, 'r') as f:
            reader = csv.DictReader(f)
            
            for row_num, row in enumerate(reader, 2):  # Start from 2 (header is row 1)
                item_id = row.get('item_id', '').strip()
                field_name = row.get('field_name', '').strip()
                value = row.get('value', '').strip()
                
                if not all([item_id, field_name, value]):
                    print(f"⚠️ Row {row_num}: Missing required fields")
                    failed += 1
                    continue
                
                print(f"🔄 Row {row_num}: {item_id} -> {field_name} = {value}")
                
                if dry_run:
                    print(f"🔍 DRY RUN: Would update item {item_id}")
                    updated += 1
                    continue
                
                try:
                    self.api.update_field_value(project_num, owner, item_id, field_name, value)
                    updated += 1
                    print(f"✅ Row {row_num}: Updated successfully")
                    time.sleep(0.5)  # Rate limiting
                except Exception as e:
                    failed += 1
                    print(f"❌ Row {row_num}: Failed - {e}")
        
        print(f"\n📊 Bulk update complete: {updated} updated, {failed} failed")
        
        if dry_run:
            print("🔍 This was a dry run - no changes were made")
    
    def export_schema(self, project_num: int, owner: str, format_type: str = 'json', output_file: str = None):
        """Export project schema"""
        logger.info(f"Exporting schema for project {project_num}")
        
        fields = self.api.get_project_fields(project_num, owner)
        
        if format_type == 'json':
            schema = {
                'project': {
                    'number': project_num,
                    'owner': owner,
                    'exported_at': datetime.now().isoformat(),
                    'fields': [{
                        'id': field.id,
                        'name': field.name,
                        'data_type': field.data_type,
                        'options': field.options or [],
                        'iterations': field.iterations or []
                    } for field in fields]
                }
            }
            output = json.dumps(schema, indent=2)
        
        elif format_type == 'markdown':
            lines = [
                f"# Project Schema: {owner}/project-{project_num}",
                f"",
                f"Exported: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
                f"",
                f"## Fields ({len(fields)} total)",
                f""
            ]
            
            for field in fields:
                lines.extend([
                    f"### {field.name}",
                    f"",
                    f"- **ID**: `{field.id}`",
                    f"- **Type**: {field.data_type}",
                ])
                
                if field.options:
                    lines.append("- **Options**:")
                    for opt in field.options:
                        lines.append(f"  - `{opt['name']}` ({opt['id']})")
                
                if field.iterations:
                    lines.append("- **Iterations**:")
                    for it in field.iterations:
                        lines.append(f"  - `{it['title']}` ({it['id']})")
                
                lines.append("")
            
            output = '\n'.join(lines)
        
        else:
            raise Exception(f"Unsupported format: {format_type}")
        
        if output_file:
            Path(output_file).write_text(output)
            print(f"✅ Schema exported to {output_file}")
        else:
            print(output)

def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description='GitHub Projects Automation - Python Implementation',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  python3 github_projects_automation.py list-items 1 ExampleOrg
  python3 github_projects_automation.py add-issue 1 ExampleOrg https://github.com/owner/repo/issues/1
  python3 github_projects_automation.py set-field 1 ExampleOrg ITEM_ID "Status" "Done"
  python3 github_projects_automation.py bulk-update 1 ExampleOrg updates.csv --dry-run
        '''
    )
    
    parser.add_argument('command', help='Command to execute')
    parser.add_argument('project_num', type=int, help='Project number')
    parser.add_argument('owner', help='Project owner (org or user)')
    parser.add_argument('args', nargs='*', help='Additional arguments')
    
    parser.add_argument('--format', default='table', choices=['table', 'json', 'csv', 'markdown'],
                        help='Output format')
    parser.add_argument('--output', help='Output file path')
    parser.add_argument('--dry-run', action='store_true', help='Preview changes without executing')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose logging')
    parser.add_argument('--version', action='version', version=f'GitHub Projects Automation v{VERSION}')
    
    args = parser.parse_args()
    
    # Validate GitHub CLI
    try:
        subprocess.run(['gh', 'auth', 'status'], capture_output=True, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("❌ GitHub CLI not authenticated or not installed")
        print("   Run: gh auth login --scopes project")
        sys.exit(1)
    
    automation = GitHubProjectsAutomation(verbose=args.verbose)
    
    try:
        if args.command == 'list-items':
            automation.list_items(args.project_num, args.owner, args.format, args.output)
        
        elif args.command == 'list-fields':
            automation.list_fields(args.project_num, args.owner, args.format, args.output)
        
        elif args.command == 'add-issue':
            if len(args.args) < 1:
                print("❌ Usage: add-issue <project_num> <owner> <issue_url>")
                sys.exit(1)
            automation.add_issue(args.project_num, args.owner, args.args[0])
        
        elif args.command == 'remove-item':
            if len(args.args) < 1:
                print("❌ Usage: remove-item <project_num> <owner> <item_id>")
                sys.exit(1)
            automation.remove_item(args.project_num, args.owner, args.args[0])
        
        elif args.command == 'set-field':
            if len(args.args) < 3:
                print("❌ Usage: set-field <project_num> <owner> <item_id> <field_name> <value>")
                sys.exit(1)
            automation.set_field(args.project_num, args.owner, args.args[0], args.args[1], args.args[2], args.dry_run)
        
        elif args.command == 'bulk-update':
            if len(args.args) < 1:
                print("❌ Usage: bulk-update <project_num> <owner> <csv_file>")
                sys.exit(1)
            automation.bulk_update(args.project_num, args.owner, args.args[0], args.dry_run)
        
        elif args.command == 'export-schema':
            automation.export_schema(args.project_num, args.owner, args.format, args.output)
        
        else:
            print(f"❌ Unknown command: {args.command}")
            parser.print_help()
            sys.exit(1)
    
    except KeyboardInterrupt:
        print("\n⚠️ Operation interrupted")
        sys.exit(130)
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        print(f"❌ Error: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()