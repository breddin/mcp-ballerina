/**
 * MCP (Model Context Protocol) Type Definitions
 * Based on MCP Specification v1.0.0
 */

export interface MCPRequest {
  jsonrpc: '2.0';
  id: string | number;
  method: string;
  params?: unknown;
}

export interface MCPResponse {
  jsonrpc: '2.0';
  id: string | number;
  result?: unknown;
  error?: MCPError;
}

export interface MCPError {
  code: number;
  message: string;
  data?: unknown;
}

export interface MCPNotification {
  jsonrpc: '2.0';
  method: string;
  params?: unknown;
}

export enum MCPErrorCode {
  ParseError = -32700,
  InvalidRequest = -32600,
  MethodNotFound = -32601,
  InvalidParams = -32602,
  InternalError = -32603,
  ServerError = -32000,
  // Custom error codes
  BallerinaNotFound = 1001,
  BuildFailed = 1002,
  TestFailed = 1003,
  DependencyConflict = 1004,
  ProjectNotFound = 2001,
  ResourceNotFound = 2002,
  AuthenticationFailed = 3001,
  AuthorizationFailed = 3002,
}

export interface InitializeParams {
  protocolVersion: string;
  capabilities: ClientCapabilities;
  clientInfo?: {
    name: string;
    version?: string;
  };
}

export interface ClientCapabilities {
  tools?: boolean;
  resources?: boolean;
  prompts?: boolean;
}

export interface ServerCapabilities {
  tools?: ToolCapabilities;
  resources?: ResourceCapabilities;
  prompts?: PromptCapabilities;
}

export interface ToolCapabilities {
  list: boolean;
  call: boolean;
}

export interface ResourceCapabilities {
  list: boolean;
  read: boolean;
  write?: boolean;
  watch?: boolean;
}

export interface PromptCapabilities {
  list: boolean;
  get: boolean;
  render: boolean;
}

export interface Tool {
  name: string;
  description?: string;
  inputSchema: {
    type: 'object';
    properties: Record<string, unknown>;
    required?: string[];
  };
}

export interface ToolCallParams {
  name: string;
  arguments: Record<string, unknown>;
}

export interface ToolResult {
  success: boolean;
  result?: unknown;
  error?: string;
}

export interface Resource {
  uri: string;
  name: string;
  description?: string;
  mimeType?: string;
  metadata?: Record<string, unknown>;
}

export interface ResourceContent {
  uri: string;
  mimeType?: string;
  data: unknown;
}

export interface PromptTemplate {
  id: string;
  name: string;
  description?: string;
  arguments: PromptArgument[];
  template: string;
  examples?: Example[];
}

export interface PromptArgument {
  name: string;
  description?: string;
  required?: boolean;
  default?: unknown;
}

export interface Example {
  arguments: Record<string, unknown>;
  result: string;
}

export interface Session {
  id: string;
  connection: Connection;
  state: SessionState;
  context: SessionContext;
  permissions: string[];
}

export interface Connection {
  id: string;
  transport: 'websocket' | 'stdio';
  send(message: MCPResponse | MCPNotification): Promise<void>;
  close(): void;
}

export interface SessionContext {
  initialized: boolean;
  capabilities: ClientCapabilities;
  clientInfo?: {
    name: string;
    version?: string;
  };
}

export enum SessionState {
  UNINITIALIZED = 'uninitialized',
  INITIALIZING = 'initializing',
  INITIALIZED = 'initialized',
  SHUTTING_DOWN = 'shutting_down',
  SHUTDOWN = 'shutdown',
}