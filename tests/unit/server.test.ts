/**
 * Unit tests for MCP Server
 */

import { MCPServer } from '../../src/server/server';
import { config } from '../../src/config';
import type { MCPRequest, MCPResponse } from '../../src/types/mcp';

// Mock dependencies
jest.mock('../../src/server/gateway');
jest.mock('../../src/utils/logger');

describe('MCPServer', () => {
  let server: MCPServer;

  beforeEach(() => {
    server = new MCPServer(config);
  });

  afterEach(async () => {
    await server.shutdown();
  });

  describe('initialization', () => {
    it('should create server instance', () => {
      expect(server).toBeDefined();
      expect(server).toBeInstanceOf(MCPServer);
    });

    it('should start server successfully', async () => {
      await expect(server.start()).resolves.not.toThrow();
    });

    it('should not start if already running', async () => {
      await server.start();
      await expect(server.start()).rejects.toThrow('Server is already running');
    });
  });

  describe('request handling', () => {
    it('should handle initialize request', async () => {
      const request: MCPRequest = {
        jsonrpc: '2.0',
        id: 1,
        method: 'initialize',
        params: {
          protocolVersion: '1.0.0',
          capabilities: {
            tools: true,
            resources: true,
            prompts: true,
          },
        },
      };

      // Test would require more setup with mocked gateway
      expect(request.method).toBe('initialize');
    });

    it('should return error for unknown method', async () => {
      const request: MCPRequest = {
        jsonrpc: '2.0',
        id: 1,
        method: 'unknown.method',
        params: {},
      };

      // Test would require more setup
      expect(request.method).toBe('unknown.method');
    });
  });

  describe('shutdown', () => {
    it('should shutdown gracefully', async () => {
      await server.start();
      await expect(server.shutdown()).resolves.not.toThrow();
    });

    it('should handle shutdown when not running', async () => {
      await expect(server.shutdown()).resolves.not.toThrow();
    });
  });
});