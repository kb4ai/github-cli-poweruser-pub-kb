import requests

org_name = 'ExampleOrg'
url = f'https://api.github.com/orgs/{org_name}/repos'
response = requests.get(url)

if response.status_code == 200:
    repos = response.json()
    repo_names = [repo['name'] for repo in repos]
    for repo_name in repo_names:
        print(repo_name)
else:
    print(f'Request failed with status code: {response.status_code}')

