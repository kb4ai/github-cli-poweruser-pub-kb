import requests
import csv
import sys
import os
import sqlite3
from datetime import datetime

GITHUB_API_URL = "https://api.github.com/repos/{owner}/{repo}/issues"
if not os.environ.get('GITHUB_TOKEN'):
    print("Error: GITHUB_TOKEN evironment variable is not set.")
    sys.exit(1)
GITHUB_TOKEN = os.environ.get('GITHUB_TOKEN')
HEADERS = {
    "Authorization": f"token {GITHUB_TOKEN}",
    "Accept": "application/vnd.github.v3+json"
}

def backup_old_file(filename):
    if os.path.exists(filename):
        timestamp = datetime.now().strftime(".bak.%Y-%m-%d--%H-%M-%S")
        os.rename(filename, filename + timestamp)

def fetch_all_issues(owner, repo):
    url = GITHUB_API_URL.format(owner=owner, repo=repo)
    params = {"state": "all", "per_page": 100}
    all_issues = []
    
    while url:
        response = requests.get(url, headers=HEADERS, params=params)
        response.raise_for_status()
        all_issues.extend(response.json())
        
        # Check if there are more pages of issues
        if 'next' in response.links:
            url = response.links['next']['url']
        else:
            url = None
    
    return all_issues

def save_to_csv(issues, filename):
    with open(filename, 'w', newline='') as csvfile:
        fieldnames = ['number', 'title', 'state', 'created_at', 'updated_at', 'body']
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        
        writer.writeheader()
        for issue in issues:
            writer.writerow({
                'number': issue['number'],
                'title': issue['title'],
                'state': issue['state'],
                'created_at': issue['created_at'],
                'updated_at': issue['updated_at'],
                'body': issue['body']
            })


def save_to_sqlite(issues, db_name):
    conn = sqlite3.connect(db_name)
    cursor = conn.cursor()

    cursor.execute('''
        CREATE TABLE IF NOT EXISTS issues (
            number INTEGER PRIMARY KEY,
            title TEXT,
            state TEXT,
            created_at TEXT,
            updated_at TEXT,
            body TEXT
        )
    ''')

    cursor.executemany('''
        INSERT INTO issues (number, title, state, created_at, updated_at, body) VALUES (?, ?, ?, ?, ?, ?)
    ''', [(issue['number'], issue['title'], issue['state'], issue['created_at'], issue['updated_at'], issue['body']) for issue in issues])

    conn.commit()
    conn.close()

if __name__ == "__main__":
    owner = 'ExampleOrg'
    if len(sys.argv) < 2:
        print("Usage: "+ sys.argv[0] + " <repository name>")
        sys.exit(1)

    repo = sys.argv[1]

    issues = fetch_all_issues(owner, repo)
    
    if not os.path.exists('exports'):
        os.makedirs('exports')
        
    export_csv_filename = f"exports/{repo}_issues.csv"
    export_db_filename = f"exports/{repo}_issues.sqlite3"

    # Backup old files if they exist
    backup_old_file(export_csv_filename)
    backup_old_file(export_db_filename)

    save_to_csv(issues, export_csv_filename)
    save_to_sqlite(issues, export_db_filename)
    
    print(f"Saved all issues of {owner}/{repo} to {export_csv_filename} and {export_db_filename}")

