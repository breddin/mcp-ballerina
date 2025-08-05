/**
 * Ballerina MCP Server Entry Point
 */

import { MCPServer } from './server';
import { config } from '../config';
import { logger } from '../utils/logger';

async function main(): Promise<void> {
  try {
    logger.info('Starting Ballerina MCP Server...');
    
    const server = new MCPServer(config);
    
    // Handle graceful shutdown
    process.on('SIGINT', async () => {
      logger.info('Received SIGINT, shutting down gracefully...');
      await server.shutdown();
      process.exit(0);
    });
    
    process.on('SIGTERM', async () => {
      logger.info('Received SIGTERM, shutting down gracefully...');
      await server.shutdown();
      process.exit(0);
    });
    
    await server.start();
    logger.info(`Ballerina MCP Server started on port ${config.port}`);
  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
}

// Start the server
main().catch((error) => {
  console.error('Unhandled error:', error);
  process.exit(1);
});