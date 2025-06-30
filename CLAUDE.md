# SECURITY GUIDELINES FOR REPOSITORY DEVELOPMENT

## CRITICAL SECURITY PRINCIPLES

### 1. NEVER COMMIT PERSONAL CONFIGURATION
- NO specific file paths (e.g., `$HOME/.env.github`, `~/.config/`, etc.)
- NO default values for configuration paths
- NO setup instructions with specific filenames
- NO personal setup details in any form

### 2. USE ONLY GENERIC ENVIRONMENT VARIABLES
- Use patterns like: `${GITHUB_TOKEN_DOTFILE}`, `${CONFIG_DIR}`, `${USER_CONFIG_FILE}`
- NEVER provide defaults: `${VAR:-/specific/path}` is FORBIDDEN
- Documentation should only state: "configure your environment variable"
- Scripts should fail gracefully if variables are not set

### 3. CONFIGURATION DOCUMENTATION STANDARDS
- "Configure ${GITHUB_TOKEN_DOTFILE} with your token file location"
- "Set ${CONFIG_DIR} to your preferred configuration directory"
- "Users must configure their own environment variables"
- NO examples with specific paths

### 4. COMMIT HISTORY HYGIENE
- Review ALL commits before pushing for configuration references
- Use `git log --all -S "specific_pattern"` to search history
- Rewrite history if any personal configuration was committed
- Maintain clean, sanitized history

### 5. CODE REVIEW REQUIREMENTS
- Every script/doc change must be reviewed for security violations
- No merge without confirming zero specific configuration references
- Use automated checks where possible

### 6. PATTERNS TO AVOID COMPLETELY
```bash
# FORBIDDEN PATTERNS:
$HOME/.env.*
~/.config/*
/Users/*/
/home/*/
C:\\Users\\
${VAR:-/specific/path}  # NO defaults with specific paths
```

### 7. APPROVED PATTERNS
```bash
# APPROVED PATTERNS:
${GITHUB_TOKEN_DOTFILE}  # No defaults
${CONFIG_DIR}  # No defaults
${USER_CONFIG_PATH}  # No defaults

# Documentation:
"Configure ${GITHUB_TOKEN_DOTFILE} with your token file location"
"Set environment variables according to your setup"
```

### 8. VERIFICATION CHECKLIST
Before any commit:
- [ ] No specific file paths anywhere in code
- [ ] No personal configuration references
- [ ] All environment variables are generic
- [ ] Documentation uses only generic instructions
- [ ] Git history clean of personal details

## LEGACY CLEANUP COMPLETED
This repository has been fully sanitized:
- All `$HOME/.env.github` replaced with `${GITHUB_TOKEN_DOTFILE}`
- All `GH_TOKEN_FILE` patterns replaced with generic variables
- Git history reviewed and cleaned
- All scripts and documentation updated

## ONGOING COMPLIANCE
Every future change must maintain these security standards. No exceptions.

---

**REMEMBER: This is a PUBLIC repository. NEVER commit anything that reveals personal setup, configuration locations, or private information.**