-- Initialize development database for MCP Ballerina
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create schemas
CREATE SCHEMA IF NOT EXISTS mcp;
CREATE SCHEMA IF NOT EXISTS analytics;

-- Create tables for session management
CREATE TABLE IF NOT EXISTS mcp.sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id VARCHAR(255) UNIQUE NOT NULL,
    user_id VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    data JSONB
);

-- Create tables for MCP tools and resources
CREATE TABLE IF NOT EXISTS mcp.tools (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    schema JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS mcp.resources (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    uri VARCHAR(500) NOT NULL,
    name VARCHAR(255),
    mime_type VARCHAR(100),
    content TEXT,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create analytics tables
CREATE TABLE IF NOT EXISTS analytics.requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    method VARCHAR(50),
    path VARCHAR(500),
    status_code INTEGER,
    response_time_ms INTEGER,
    user_agent TEXT,
    ip_address INET,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS analytics.errors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    error_type VARCHAR(100),
    error_message TEXT,
    stack_trace TEXT,
    context JSONB,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_sessions_session_id ON mcp.sessions(session_id);
CREATE INDEX IF NOT EXISTS idx_sessions_expires_at ON mcp.sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_resources_uri ON mcp.resources(uri);
CREATE INDEX IF NOT EXISTS idx_requests_timestamp ON analytics.requests(timestamp);
CREATE INDEX IF NOT EXISTS idx_errors_timestamp ON analytics.errors(timestamp);

-- Insert sample data for development
INSERT INTO mcp.tools (name, description, schema) VALUES 
('code_analysis', 'Analyze Ballerina source code', '{"type": "object", "properties": {"file": {"type": "string"}}}'),
('language_server', 'Language server integration', '{"type": "object", "properties": {"method": {"type": "string"}, "params": {"type": "object"}}}'),
('refactoring', 'Code refactoring tools', '{"type": "object", "properties": {"operation": {"type": "string"}, "target": {"type": "string"}}}')
ON CONFLICT DO NOTHING;

INSERT INTO mcp.resources (uri, name, mime_type, content) VALUES 
('ballerina://stdlib/http', 'HTTP Library Documentation', 'text/markdown', '# HTTP Library\nBallerina HTTP library documentation...'),
('ballerina://stdlib/io', 'IO Library Documentation', 'text/markdown', '# IO Library\nBallerina IO library documentation...'),
('ballerina://examples/hello-world', 'Hello World Example', 'text/plain', 'import ballerina/io;\n\npublic function main() {\n    io:println("Hello, World!");\n}')
ON CONFLICT DO NOTHING;