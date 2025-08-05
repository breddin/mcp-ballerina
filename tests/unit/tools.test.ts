/**
 * Unit tests for Tool Registry
 */

import { ToolRegistry } from '../../src/tools/registry';
import { z } from 'zod';
import type { ToolResult } from '../../src/types/mcp';

describe('ToolRegistry', () => {
  let registry: ToolRegistry;

  beforeEach(() => {
    registry = new ToolRegistry();
  });

  describe('tool registration', () => {
    it('should register a tool', () => {
      const testTool = {
        name: 'test.tool',
        description: 'Test tool',
        inputSchema: {
          type: 'object' as const,
          properties: {
            input: { type: 'string' },
          },
          required: ['input'],
        },
        handler: async (args: any): Promise<ToolResult> => ({
          success: true,
          result: args,
        }),
        schema: z.object({ input: z.string() }),
      };

      registry.register(testTool as any);
      expect(registry.hasTool('test.tool')).toBe(true);
    });

    it('should list registered tools', async () => {
      const testTool = {
        name: 'test.tool',
        description: 'Test tool',
        inputSchema: {
          type: 'object' as const,
          properties: {},
          required: [],
        },
        handler: async (): Promise<ToolResult> => ({ success: true }),
        schema: z.object({}),
      };

      registry.register(testTool as any);
      const tools = await registry.list();
      
      expect(tools).toHaveLength(1);
      expect(tools[0].name).toBe('test.tool');
    });
  });

  describe('tool execution', () => {
    it('should execute a registered tool', async () => {
      const handler = jest.fn(async () => ({ success: true, result: 'test' }));
      
      const testTool = {
        name: 'test.tool',
        description: 'Test tool',
        inputSchema: {
          type: 'object' as const,
          properties: {
            input: { type: 'string' },
          },
          required: ['input'],
        },
        handler,
        schema: z.object({ input: z.string() }),
      };

      registry.register(testTool as any);
      
      const result = await registry.call('test.tool', { input: 'test' });
      
      expect(result.success).toBe(true);
      expect(result.result).toBe('test');
      expect(handler).toHaveBeenCalledWith({ input: 'test' });
    });

    it('should return error for non-existent tool', async () => {
      const result = await registry.call('non.existent', {});
      
      expect(result.success).toBe(false);
      expect(result.error).toContain('Tool not found');
    });

    it('should validate tool arguments', async () => {
      const testTool = {
        name: 'test.tool',
        description: 'Test tool',
        inputSchema: {
          type: 'object' as const,
          properties: {
            required: { type: 'string' },
          },
          required: ['required'],
        },
        handler: async () => ({ success: true }),
        schema: z.object({ required: z.string() }),
      };

      registry.register(testTool as any);
      
      const result = await registry.call('test.tool', { wrong: 'field' });
      
      expect(result.success).toBe(false);
      expect(result.error).toContain('Invalid arguments');
    });
  });

  describe('tool management', () => {
    it('should clear all tools', () => {
      const testTool = {
        name: 'test.tool',
        description: 'Test tool',
        inputSchema: {
          type: 'object' as const,
          properties: {},
          required: [],
        },
        handler: async () => ({ success: true }),
        schema: z.object({}),
      };

      registry.register(testTool as any);
      expect(registry.hasTool('test.tool')).toBe(true);
      
      registry.clear();
      expect(registry.hasTool('test.tool')).toBe(false);
    });

    it('should get tool schema', () => {
      const schema = z.object({ test: z.string() });
      const testTool = {
        name: 'test.tool',
        description: 'Test tool',
        inputSchema: {
          type: 'object' as const,
          properties: {},
          required: [],
        },
        handler: async () => ({ success: true }),
        schema,
      };

      registry.register(testTool as any);
      const retrievedSchema = registry.getToolSchema('test.tool');
      
      expect(retrievedSchema).toBe(schema);
    });
  });
});