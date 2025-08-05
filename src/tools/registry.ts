/**
 * Tool Registry - Manages tool registration and execution
 */

import type { Tool, ToolResult } from '../types/mcp';
import { logger } from '../utils/logger';
import { z } from 'zod';

export class ToolRegistry {
  private tools: Map<string, RegisteredTool> = new Map();

  interface RegisteredTool extends Tool {
    handler: (args: any) => Promise<ToolResult>;
    schema: z.ZodSchema;
  }

  register(tool: RegisteredTool): void {
    if (this.tools.has(tool.name)) {
      logger.warn(`Overwriting existing tool: ${tool.name}`);
    }
    
    this.tools.set(tool.name, tool);
    logger.info(`Registered tool: ${tool.name}`);
  }

  async list(): Promise<Tool[]> {
    return Array.from(this.tools.values()).map(({ handler, schema, ...tool }) => tool);
  }

  async call(name: string, args: any): Promise<ToolResult> {
    const tool = this.tools.get(name);
    
    if (!tool) {
      return {
        success: false,
        error: `Tool not found: ${name}`,
      };
    }

    try {
      // Validate arguments
      const validatedArgs = tool.schema.parse(args);
      
      // Execute tool
      const result = await tool.handler(validatedArgs);
      
      logger.info(`Tool ${name} executed successfully`);
      return result;
    } catch (error: any) {
      logger.error(`Tool ${name} execution failed:`, error);
      
      if (error instanceof z.ZodError) {
        return {
          success: false,
          error: `Invalid arguments: ${error.errors.map(e => e.message).join(', ')}`,
        };
      }
      
      return {
        success: false,
        error: error.message || 'Tool execution failed',
      };
    }
  }

  getToolSchema(name: string): z.ZodSchema | undefined {
    return this.tools.get(name)?.schema;
  }

  hasT tool(name: string): boolean {
    return this.tools.has(name);
  }

  clear(): void {
    this.tools.clear();
  }
}

interface RegisteredTool extends Tool {
  handler: (args: any) => Promise<ToolResult>;
  schema: z.ZodSchema;
}