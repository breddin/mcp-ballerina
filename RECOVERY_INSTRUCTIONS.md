# Disaster Recovery Instructions for MCP Ballerina Project

## Critical Information for System Recovery

In case of catastrophic host failure, use these instructions to resume development from any point.

## Current Sprint Status (Sprint 7 - Security Analysis)

### Swarm Information
- **Current Swarm ID**: `swarm_1754516618828_8gbpfejh6`
- **Topology**: hierarchical
- **Max Agents**: 8
- **Strategy**: specialized
- **Timestamp**: 2025-08-06T21:43:38.828Z

### Active Agents
1. **security-analyzer** (ID: `agent_1754516623502_pwfl29`)
   - Capabilities: SAST, vulnerability-detection, security-patterns
2. **vulnerability-scanner** (ID: `agent_1754516628535_eyzln3`)
   - Capabilities: CVE-detection, dependency-scanning, OWASP
3. **security-reporter** (ID: `agent_1754516632993_lum5h3`)
   - Capabilities: security-reports, compliance, remediation-guidance

### Memory Storage Keys
- **Sprint 7 Swarm Info**: `mcp-ballerina:sprint7_swarm_info`
  - Storage ID: 4228
  - TTL: 7 days (604800 seconds)
  - Contains: swarmId, agents, repository info, last commit

## Repository Information
- **Repository**: https://github.com/breddin/mcp-ballerina
- **Branch**: main
- **Last Known Commit**: 9edc966 (Sprint 6 completion)

## Completed Sprints

### Sprint 3-4: Code Analysis & Testing
- ✅ AST Parser implementation
- ✅ Semantic Analyzer
- ✅ LSP Handlers
- ✅ MCP Integration (12 tools)
- ✅ 56+ test cases
- **GitHub Issue**: #14

### Sprint 5: Advanced Refactoring Tools
- ✅ Refactoring Engine (Extract Method, Inline, Rename)
- ✅ Code Templates (REST, Database, Error Handling)
- ✅ Quick Fixes Provider
- ✅ 35+ test cases
- **GitHub Issue**: #15
- **Commit**: 16abf35

### Sprint 6: Real-time Collaboration
- ✅ WebSocket Server
- ✅ Operational Transform Engine
- ✅ Presence Manager
- **GitHub Issue**: #16
- **Commit**: 9edc966

### Sprint 7: Security Analysis (IN PROGRESS)
- ✅ Security Analyzer (SAST implementation)
- ✅ Vulnerability Scanner (CVE/GHSA detection)
- ✅ Security Reporter (Multiple formats)
- ⏳ Tests pending
- ⏳ Commit pending

## Recovery Steps

### 1. Clone Repository
```bash
git clone https://github.com/breddin/mcp-ballerina.git
cd mcp-ballerina
```

### 2. Install Dependencies
```bash
# Install Ballerina
curl -sSL https://ballerina.io/installer.sh | bash

# Install Claude Flow
npm install -g @anthropic/claude-flow@alpha

# Add MCP server
claude mcp add claude-flow npx claude-flow@alpha mcp start
```

### 3. Restore Swarm State
```bash
# Retrieve stored swarm information
npx claude-flow@alpha memory retrieve --key sprint7_swarm_info --namespace mcp-ballerina

# Reinitialize swarm with saved configuration
npx claude-flow@alpha swarm init --topology hierarchical --max-agents 8 --strategy specialized
```

### 4. Resume Sprint 7
```bash
# Complete Sprint 7 testing and documentation
npx claude-flow@alpha swarm 'Complete Sprint 7: Test security features and commit' --claude --parallel

# Or start fresh with next sprint
npx claude-flow@alpha swarm 'Sprint 8: Performance optimization' --claude --parallel
```

## File Structure

```
mcp-ballerina/
├── modules/
│   ├── code_analysis/       # Sprint 3-4
│   │   ├── ast_parser.bal
│   │   ├── semantic_analyzer.bal
│   │   ├── lsp_handlers.bal
│   │   └── mcp_integration.bal
│   ├── refactoring/         # Sprint 5
│   │   ├── refactor_engine.bal
│   │   ├── code_templates.bal
│   │   └── quick_fixes.bal
│   ├── collaboration/       # Sprint 6
│   │   ├── websocket_server.bal
│   │   ├── ot_engine.bal
│   │   └── presence_manager.bal
│   └── security/           # Sprint 7
│       ├── security_analyzer.bal
│       ├── vulnerability_scanner.bal
│       └── security_reporter.bal
├── tests/
│   ├── code_analysis/
│   ├── refactoring/
│   └── security/           # To be created
└── docs/
    └── sparc/

```

## Environment Variables

```bash
export GITHUB_TOKEN=ghp_... # Your GitHub token
export CLAUDE_API_KEY=...   # If using API directly
```

## Testing Commands

```bash
# Run all tests
bal test

# Run specific module tests
bal test modules/security/

# Run with coverage
bal test --code-coverage
```

## Next Sprints (Planned)

### Sprint 8: Performance Optimization
- Caching strategies
- Lazy loading
- Parallel processing
- Memory optimization

### Sprint 9: Documentation & Examples
- API documentation
- Usage examples
- Best practices guide
- Video tutorials

### Sprint 10: Integration & Deployment
- CI/CD pipeline
- Docker containerization
- Kubernetes deployment
- Monitoring setup

## Troubleshooting

### If swarm fails to restore:
1. Create new swarm with same configuration
2. Spawn agents manually using agent IDs above
3. Check GitHub issues for latest status

### If tests fail:
1. Check Ballerina version compatibility
2. Verify all dependencies installed
3. Review test logs in `target/test-results/`

### If commits fail:
1. Ensure GitHub token is valid
2. Check repository permissions
3. Pull latest changes: `git pull --rebase origin main`

## Contact & Support

- **Repository Issues**: https://github.com/breddin/mcp-ballerina/issues
- **Claude Flow Docs**: https://github.com/ruvnet/claude-flow
- **Ballerina Docs**: https://ballerina.io/learn/

## Critical Commands Reference

```bash
# Save current state
npx claude-flow@alpha memory store --key recovery_checkpoint --value "$(git rev-parse HEAD)"

# List all memory keys
npx claude-flow@alpha memory list --namespace mcp-ballerina

# Export swarm state
npx claude-flow@alpha swarm export > swarm-backup.json

# Monitor swarm health
npx claude-flow@alpha swarm monitor --interval 5
```

---

**Last Updated**: 2025-08-06T21:48:00Z
**Updated By**: Claude Code Agent (Sprint 7)
**Recovery Document Version**: 1.0.0