# Production Deployment Guide

Guidelines for deploying GitHub CLI automation scripts in production environments.

## 🔐 Security Best Practices

### Authentication
```bash
# Use environment variables for tokens
export GITHUB_TOKEN="your_token_here"

# Avoid hardcoding tokens in scripts
# ❌ Bad
TOKEN="ghp_xxxxxxxxxxxx"

# ✅ Good  
TOKEN="${GITHUB_TOKEN:-$(gh auth token)}"
```

### Permissions
- Use **least privilege** tokens with only required scopes
- For read-only operations: `read:project` scope
- For write operations: `project` scope  
- Regularly rotate authentication tokens

## 🏗️ Infrastructure Setup

### CI/CD Integration
```yaml
# GitHub Actions example
name: Project Automation
on:
  issues:
    types: [opened, closed]

jobs:
  update-project:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup GitHub CLI
        run: |
          gh auth login --with-token <<< "${{ secrets.GITHUB_TOKEN }}"
          gh auth refresh -s project
      - name: Add issue to project
        run: |
          ./github-projects-item-management.sh add-issue 1 "${{ github.repository_owner }}" "${{ github.event.issue.html_url }}"
```

### Error Handling & Monitoring
```bash
# Enable comprehensive logging
export GITHUB_CLI_LOG_LEVEL=debug
export GITHUB_CLI_LOG_FILE="/var/log/github-automation.log"

# Set up log rotation
logrotate -f /etc/logrotate.d/github-automation

# Monitor script execution
./github-projects-item-management.sh add-issue 1 "@me" "$URL" || {
    echo "ERROR: Failed to add issue $URL" >&2
    # Send alert to monitoring system
    curl -X POST "$WEBHOOK_URL" -d "GitHub automation failed: $URL"
    exit 1
}
```

## ⚡ Performance Optimization

### Rate Limiting
```bash
# Respect GitHub API rate limits
# Default: 5000 requests/hour for authenticated requests

# For bulk operations, add delays
for issue in "${issues[@]}"; do
    ./github-projects-item-management.sh add-issue 1 "@me" "$issue"
    sleep 1  # Avoid rate limiting
done

# Use bulk operations when possible
./github-projects-item-management.sh bulk-add-issues 1 "@me" issues.txt
```

### Caching
```bash
# Cache project metadata to reduce API calls
PROJECT_CACHE="/tmp/github-project-cache.json"
if [[ ! -f "$PROJECT_CACHE" || $(($(date +%s) - $(stat -c %Y "$PROJECT_CACHE"))) -gt 3600 ]]; then
    ./github-projects-field-discovery.sh export-schema 1 "@me" --format json > "$PROJECT_CACHE"
fi
```

## 🔄 Backup & Recovery

### Data Backup
```bash
# Regular project state backup
./github-projects-item-management.sh list-items 1 "@me" --format json > "backup-$(date +%Y%m%d).json"

# Field values backup
./github-projects-field-management.sh export-field-values 1 "@me" --format csv > "fields-$(date +%Y%m%d).csv"
```

### Recovery Procedures
```bash
# Restore from backup (dry-run first)
./github-projects-field-management.sh bulk-update-from-csv 1 "@me" "fields-backup.csv" --dry-run
./github-projects-field-management.sh bulk-update-from-csv 1 "@me" "fields-backup.csv"
```

## 📊 Monitoring & Alerting

### Health Checks
```bash
#!/bin/bash
# health-check.sh - Verify GitHub CLI automation health

# Test authentication
gh auth status || exit 1

# Test project access
gh project view 1 --owner "@me" > /dev/null || exit 1

# Test script functionality
./github-projects-item-management.sh list-items 1 "@me" --format json > /dev/null || exit 1

echo "✅ GitHub CLI automation healthy"
```

### Metrics Collection
```bash
# Track automation metrics
echo "$(date '+%Y-%m-%d %H:%M:%S'),add-issue,success,$ITEM_COUNT" >> /var/log/github-metrics.csv

# Integration with monitoring systems
curl -X POST "https://monitoring.example.com/metrics" \
  -H "Content-Type: application/json" \
  -d '{"metric": "github.automation.items_added", "value": '$ITEM_COUNT', "timestamp": '$(date +%s)'}'
```

## 🧪 Testing Strategy

### Unit Testing
```bash
# Test individual script functions
test_add_issue() {
    local result
    result=$(./github-projects-item-management.sh add-issue 1 "@me" "$TEST_ISSUE_URL" --dry-run)
    [[ "$result" =~ "Would add issue" ]] || return 1
}

# Run test suite
./run-tests.sh
```

### Integration Testing
```bash
# Test complete workflows
test_full_workflow() {
    # Create test issue
    ISSUE_URL=$(gh issue create --repo "$TEST_REPO" --title "Test Issue" --body "Test" --json url --jq .url)
    
    # Add to project
    ./github-projects-item-management.sh add-issue 1 "@me" "$ISSUE_URL"
    
    # Verify addition
    ./github-projects-item-management.sh list-items 1 "@me" --format json | jq -r '.[].content.url' | grep -q "$ISSUE_URL"
    
    # Cleanup
    gh issue close "$ISSUE_URL" --repo "$TEST_REPO"
}
```

## 🚀 Deployment Checklist

### Pre-deployment
- [ ] Authentication tokens configured
- [ ] Required scopes verified (`project` for write ops)
- [ ] Scripts tested in staging environment
- [ ] Monitoring and alerting configured
- [ ] Backup procedures in place
- [ ] Error handling tested

### Deployment
- [ ] Deploy scripts to production servers
- [ ] Configure cron jobs or CI/CD triggers
- [ ] Verify health checks pass
- [ ] Test critical workflows
- [ ] Monitor logs for errors

### Post-deployment
- [ ] Verify automation is working as expected
- [ ] Check performance metrics
- [ ] Review error logs
- [ ] Document any issues or improvements
- [ ] Update runbooks if needed

## 📋 Maintenance

### Regular Tasks
- **Weekly**: Review error logs and performance metrics
- **Monthly**: Rotate authentication tokens
- **Quarterly**: Update scripts and dependencies
- **Annually**: Review and update security practices

### Troubleshooting
```bash
# Enable debug logging
export DEBUG=1
./github-projects-item-management.sh add-issue 1 "@me" "$URL" --verbose

# Check GitHub CLI status
gh auth status
gh api rate_limit

# Verify project permissions
gh project view 1 --owner "@me"
```

## 📚 Additional Resources

- [GitHub CLI Authentication Guide](https://cli.github.com/manual/gh_auth)
- [GitHub GraphQL API Rate Limits](https://docs.github.com/en/graphql/overview/resource-limitations)
- [GitHub Actions Security Best Practices](https://docs.github.com/en/actions/security-guides)