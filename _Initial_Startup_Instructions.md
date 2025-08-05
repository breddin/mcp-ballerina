npm install -g @anthropic-ai/claude-code

claude --dangerously-skip-permissions

npx claude-flow@alpha init --force --project-name "mcp_ballerina"

npx claude-flow@alpha hive-mind spawn "You are architecting and building an MCP server for the Ballerina programming language. Your requirements, specifications, and progress are in the GitHub repository breddin/mcp_ballerina. Access to that repository will be through GitHub API using a Bearer token stored in the _GITHUB_PAT environment variable. Going forward, you will post all code generated to the repository, as well as post all documents (Research, status, resume instructions between sprints, etc.) to the repository's Issues. First confirm access to the repo, reporting all avenues you attempt. If all fail, abort until we can remediate. Second, review existing documents in the project, prepare roadmap of ongoing sprints. Post that roadmap to the repo's Issues. As each sprint is completed, we will check it off and continue posting instructions to successfully resume into the next sprint" --namespace mcp_ballerina --agents 8 --claude
