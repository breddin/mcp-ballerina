/**
 * Server Configuration
 */

import { config as dotenvConfig } from 'dotenv';

// Load environment variables
dotenvConfig();

export interface ServerConfig {
  port: number;
  host: string;
  transport: 'websocket' | 'stdio';
  ballerinaHome?: string;
  javaHome?: string;
  logLevel: string;
  maxConnections: number;
  requestTimeout: number;
  cache: {
    enabled: boolean;
    ttl: number;
    maxSize: number;
  };
}

export const config: ServerConfig = {
  port: parseInt(process.env.MCP_PORT || '3000', 10),
  host: process.env.MCP_HOST || 'localhost',
  transport: (process.env.MCP_TRANSPORT || 'websocket') as 'websocket' | 'stdio',
  ballerinaHome: process.env.BAL_HOME,
  javaHome: process.env.JAVA_HOME,
  logLevel: process.env.LOG_LEVEL || 'info',
  maxConnections: parseInt(process.env.MAX_CONNECTIONS || '100', 10),
  requestTimeout: parseInt(process.env.REQUEST_TIMEOUT || '30000', 10),
  cache: {
    enabled: process.env.CACHE_ENABLED !== 'false',
    ttl: parseInt(process.env.CACHE_TTL || '60000', 10),
    maxSize: parseInt(process.env.CACHE_MAX_SIZE || '1000', 10),
  },
};