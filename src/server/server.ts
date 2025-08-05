/**
 * Core MCP Server Implementation
 */

import type {
  MCPRequest,
  MCPResponse,
  MCPError,
  Session,
  Connection,
  InitializeParams,
  ServerCapabilities,
} from '../types/mcp';
import { MCPErrorCode } from '../types/mcp';
import { ConnectionGateway } from './gateway';
import { RequestRouter } from './router';
import { SessionManager } from './session';
import { ToolRegistry } from '../tools/registry';
import { ResourceManager } from '../resources/manager';
import { PromptHandler } from '../services/prompt-handler';
import { logger } from '../utils/logger';
import type { ServerConfig } from '../config';

export class MCPServer {
  private gateway: ConnectionGateway;
  private router: RequestRouter;
  private sessionManager: SessionManager;
  private toolRegistry: ToolRegistry;
  private resourceManager: ResourceManager;
  private promptHandler: PromptHandler;
  private config: ServerConfig;
  private isRunning: boolean = false;

  constructor(config: ServerConfig) {
    this.config = config;
    this.gateway = new ConnectionGateway(config);
    this.router = new RequestRouter();
    this.sessionManager = new SessionManager();
    this.toolRegistry = new ToolRegistry();
    this.resourceManager = new ResourceManager();
    this.promptHandler = new PromptHandler();

    this.setupRoutes();
    this.registerTools();
    this.loadResources();
  }

  private setupRoutes(): void {
    // Initialize
    this.router.register('initialize', async (params: unknown, session: Session) => {
      return this.handleInitialize(params as InitializeParams, session);
    });

    // Tools
    this.router.register('tools/list', async (_params: unknown, session: Session) => {
      this.validateSession(session);
      return { tools: await this.toolRegistry.list() };
    });

    this.router.register('tools/call', async (params: any, session: Session) => {
      this.validateSession(session);
      return await this.toolRegistry.call(params.name, params.arguments);
    });

    // Resources
    this.router.register('resources/list', async (params: any, session: Session) => {
      this.validateSession(session);
      return { resources: await this.resourceManager.list(params?.filter) };
    });

    this.router.register('resources/read', async (params: any, session: Session) => {
      this.validateSession(session);
      return await this.resourceManager.read(params.uri);
    });

    // Prompts
    this.router.register('prompts/list', async (_params: unknown, session: Session) => {
      this.validateSession(session);
      return { prompts: await this.promptHandler.list() };
    });

    this.router.register('prompts/get', async (params: any, session: Session) => {
      this.validateSession(session);
      return await this.promptHandler.get(params.id);
    });

    // Shutdown
    this.router.register('shutdown', async (_params: unknown, session: Session) => {
      this.validateSession(session);
      session.state = 'shutting_down' as any;
      setTimeout(() => this.sessionManager.destroy(session.id), 1000);
      return { message: 'Server shutting down' };
    });
  }

  private registerTools(): void {
    // Register Ballerina tools
    // These will be implemented in the tools module
    logger.info('Registering Ballerina tools...');
  }

  private loadResources(): void {
    // Load initial resources
    logger.info('Loading resources...');
  }

  private async handleInitialize(
    params: InitializeParams,
    session: Session
  ): Promise<{ capabilities: ServerCapabilities }> {
    if (session.state !== 'uninitialized' as any) {
      throw this.createError(
        MCPErrorCode.InvalidRequest,
        'Server already initialized'
      );
    }

    session.state = 'initializing' as any;
    session.context.capabilities = params.capabilities;
    session.context.clientInfo = params.clientInfo;

    const capabilities: ServerCapabilities = {
      tools: {
        list: true,
        call: true,
      },
      resources: {
        list: true,
        read: true,
        write: true,
        watch: true,
      },
      prompts: {
        list: true,
        get: true,
        render: true,
      },
    };

    session.state = 'initialized' as any;
    session.context.initialized = true;

    logger.info(`Session ${session.id} initialized`, {
      clientInfo: params.clientInfo,
    });

    return { capabilities };
  }

  private validateSession(session: Session): void {
    if (!session.context.initialized) {
      throw this.createError(
        MCPErrorCode.InvalidRequest,
        'Server not initialized'
      );
    }
  }

  private createError(code: number, message: string, data?: unknown): MCPError {
    return { code, message, data };
  }

  async start(): Promise<void> {
    if (this.isRunning) {
      throw new Error('Server is already running');
    }

    await this.gateway.start();
    this.isRunning = true;

    // Handle incoming connections
    this.gateway.on('connection', (connection: Connection) => {
      const session = this.sessionManager.create(connection);
      
      connection.on('request', async (request: MCPRequest) => {
        try {
          const response = await this.handleRequest(request, session);
          await connection.send(response);
        } catch (error) {
          const errorResponse = this.createErrorResponse(request.id, error);
          await connection.send(errorResponse);
        }
      });

      connection.on('close', () => {
        this.sessionManager.destroy(session.id);
      });
    });
  }

  private async handleRequest(request: MCPRequest, session: Session): Promise<MCPResponse> {
    logger.debug(`Handling request: ${request.method}`, { id: request.id });

    try {
      const result = await this.router.process(request, session);
      return {
        jsonrpc: '2.0',
        id: request.id,
        result,
      };
    } catch (error) {
      throw error;
    }
  }

  private createErrorResponse(id: string | number, error: any): MCPResponse {
    const mcpError: MCPError = error.code
      ? error
      : {
          code: MCPErrorCode.InternalError,
          message: error.message || 'Internal server error',
          data: error,
        };

    return {
      jsonrpc: '2.0',
      id,
      error: mcpError,
    };
  }

  async shutdown(): Promise<void> {
    if (!this.isRunning) {
      return;
    }

    logger.info('Shutting down server...');
    
    // Close all sessions
    this.sessionManager.destroyAll();
    
    // Stop gateway
    await this.gateway.stop();
    
    this.isRunning = false;
    logger.info('Server shutdown complete');
  }
}