# OpenCode Agent Safety Rules

This file contains safety guidelines and rules for OpenCode agents working in this dotfiles repository.

## Agent Roles

### Plan Agent (Read-Only Analysis)
The Plan agent is designed for **analysis, planning, and code review only**. It has NO permission to modify files or execute destructive commands.

**Allowed Actions:**
- Read files and analyze code
- Run read-only bash commands (ls, cat, grep, git status, git diff, etc.)
- Provide suggestions and recommendations
- Create execution plans and architecture diagrams

**Prohibited Actions:**
- Creating, modifying, or deleting any files
- Running write operations (mkdir, touch, rm, mv, cp)
- Executing git commits, pushes, or merges
- Installing packages or dependencies
- Changing file permissions or ownership
- Running any command with sudo

### Build Agent (Full Development Mode)
The Build agent has full development permissions but includes safety checks for dangerous operations.

**Safety Features:**
- Requires confirmation before deleting files (rm, rm -rf)
- Asks before using sudo or changing permissions
- Blocks catastrophic commands (rm -rf /, sudo rm -rf, etc.)
- Confirms before force-pushing to git repositories
- Prompts before running destructive infrastructure commands

## Dangerous Commands Reference

### Always Denied (Both Agents)
- `rm -rf /` - System root deletion
- `rm -rf /*` - All system files deletion
- `rm -rf ~` - Home directory deletion
- `sudo rm -rf` - Administrator-level recursive deletion
- `> /dev/sda` - Disk device overwrite
- `dd if=*` - Low-level disk operations
- `git push --force` - Force push (history rewriting)

### Plan Agent: Denied
- **All write operations**: rm, mkdir, touch, mv, cp, ln
- **Permission changes**: chmod, chown
- **Admin privileges**: sudo, su
- **Package installation**: npm/pip/apt/brew install
- **Git modifications**: commit, push, pull, merge, rebase
- **Docker operations**: rm, rmi, prune

### Build Agent: Ask for Confirmation
- **Deletions**: rm, rm -rf, rmdir
- **Admin operations**: sudo, chmod, chown
- **Critical git ops**: git push, git reset --hard, git clean
- **Docker/K8s destructive ops**: docker rm, kubectl delete
- **Infrastructure changes**: terraform destroy/apply

## Best Practices

1. **Plan Agent Workflow:**
   - Use Plan agent first to analyze and create implementation plans
   - Review suggestions thoroughly before switching to Build agent
   - Let Plan agent explore the codebase without fear of accidental changes

2. **Build Agent Workflow:**
   - Review Plan agent suggestions before implementing
   - Pay attention to confirmation prompts for dangerous commands
   - Use version control and make regular commits
   - Test changes in isolated environments when possible

3. **General Safety:**
   - Never bypass permission checks without understanding the consequences
   - Always backup important data before major changes
   - Use descriptive commit messages for easy rollback
   - Review diffs before committing changes

## Emergency Procedures

If a dangerous command is accidentally executed:
1. Immediately stop the operation (Ctrl+C)
2. Assess the damage using read-only commands
3. Use git to restore files if they were tracked
4. Restore from backups if necessary
5. Review what went wrong to prevent recurrence

## Repository-Specific Guidelines

This is a dotfiles repository containing:
- Shell configurations (zsh, bash)
- Editor configurations (nvim, vim)
- Git configurations
- OpenCode configurations
- Installation scripts

**Special Considerations:**
- Changes here affect the entire development environment
- Test changes in a safe environment before applying globally
- Keep configurations portable and well-documented
- Use symbolic links for easy updates across systems
