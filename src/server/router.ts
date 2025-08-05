/**
 * Request Router - Routes MCP requests to appropriate handlers
 */

import type { MCPRequest, MCPResponse, MCPError, Session } from '../types/mcp';
import { MCPErrorCode } from '../types/mcp';
import { logger } from '../utils/logger';

type RequestHandler = (params: unknown, session: Session) => Promise<unknown>;
type Middleware = (request: MCPRequest, response: MCPResponse) => void;

export class RequestRouter {
  private routes: Map<string, RequestHandler> = new Map();
  private middleware: Middleware[] = [];

  register(method: string, handler: RequestHandler): void {
    if (this.routes.has(method)) {
      logger.warn(`Overwriting existing handler for method: ${method}`);
    }
    this.routes.set(method, handler);
    logger.debug(`Registered handler for method: ${method}`);
  }

  use(middleware: Middleware): void {
    this.middleware.push(middleware);
  }

  async process(request: MCPRequest, session: Session): Promise<unknown> {
    const handler = this.routes.get(request.method);
    
    if (!handler) {
      throw this.createError(
        MCPErrorCode.MethodNotFound,
        `Method not found: ${request.method}`
      );
    }

    try {
      // Validate request
      this.validateRequest(request);
      
      // Execute handler
      const result = await handler(request.params, session);
      
      // Apply middleware
      const response: MCPResponse = {
        jsonrpc: '2.0',
        id: request.id,
        result,
      };
      
      for (const mw of this.middleware) {
        mw(request, response);
      }
      
      return result;
    } catch (error: any) {
      logger.error(`Error processing request ${request.method}:`, error);
      
      // Re-throw MCP errors as-is
      if (error.code && error.message) {
        throw error;
      }
      
      // Wrap other errors
      throw this.createError(
        MCPErrorCode.InternalError,
        error.message || 'Internal server error',
        error
      );
    }
  }

  private validateRequest(request: MCPRequest): void {
    if (request.jsonrpc !== '2.0') {
      throw this.createError(
        MCPErrorCode.InvalidRequest,
        'Invalid JSON-RPC version'
      );
    }

    if (!request.method || typeof request.method !== 'string') {
      throw this.createError(
        MCPErrorCode.InvalidRequest,
        'Missing or invalid method'
      );
    }

    if (request.id === undefined || request.id === null) {
      throw this.createError(
        MCPErrorCode.InvalidRequest,
        'Missing request id'
      );
    }
  }

  private createError(code: number, message: string, data?: unknown): MCPError {
    return { code, message, data };
  }

  listMethods(): string[] {
    return Array.from(this.routes.keys());
  }
}