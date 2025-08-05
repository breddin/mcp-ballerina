/**
 * Connection Gateway - Handles WebSocket and stdio connections
 */

import { WebSocketServer, WebSocket } from 'ws';
import { EventEmitter } from 'events';
import type { Connection, MCPRequest, MCPResponse } from '../types/mcp';
import { logger } from '../utils/logger';
import type { ServerConfig } from '../config';

export class ConnectionGateway extends EventEmitter {
  private wsServer?: WebSocketServer;
  private connections: Map<string, Connection> = new Map();
  private config: ServerConfig;
  private connectionIdCounter = 0;

  constructor(config: ServerConfig) {
    super();
    this.config = config;
  }

  async start(): Promise<void> {
    if (this.config.transport === 'websocket') {
      this.startWebSocketServer();
    } else if (this.config.transport === 'stdio') {
      this.startStdioServer();
    } else {
      throw new Error(`Unsupported transport: ${this.config.transport}`);
    }
  }

  private startWebSocketServer(): void {
    this.wsServer = new WebSocketServer({
      port: this.config.port,
      host: this.config.host,
    });

    this.wsServer.on('connection', (ws: WebSocket) => {
      const connection = this.createWebSocketConnection(ws);
      this.handleConnection(connection);
    });

    this.wsServer.on('error', (error) => {
      logger.error('WebSocket server error:', error);
    });

    logger.info(`WebSocket server listening on ${this.config.host}:${this.config.port}`);
  }

  private startStdioServer(): void {
    const connection = this.createStdioConnection();
    this.handleConnection(connection);
    logger.info('Stdio server started');
  }

  private createWebSocketConnection(ws: WebSocket): Connection {
    const id = `ws-${++this.connectionIdCounter}`;
    
    const connection: Connection = {
      id,
      transport: 'websocket',
      send: async (message: MCPResponse) => {
        return new Promise((resolve, reject) => {
          ws.send(JSON.stringify(message), (error) => {
            if (error) reject(error);
            else resolve();
          });
        });
      },
      close: () => {
        ws.close();
      },
    };

    // Extend connection with EventEmitter capabilities
    const connectionWithEvents = Object.assign(new EventEmitter(), connection);

    ws.on('message', (data: Buffer) => {
      try {
        const request = JSON.parse(data.toString()) as MCPRequest;
        connectionWithEvents.emit('request', request);
      } catch (error) {
        logger.error('Failed to parse WebSocket message:', error);
      }
    });

    ws.on('close', () => {
      connectionWithEvents.emit('close');
      this.connections.delete(id);
    });

    ws.on('error', (error) => {
      logger.error(`WebSocket connection ${id} error:`, error);
    });

    this.connections.set(id, connectionWithEvents as any);
    return connectionWithEvents as any;
  }

  private createStdioConnection(): Connection {
    const id = 'stdio';
    
    const connection: Connection = {
      id,
      transport: 'stdio',
      send: async (message: MCPResponse) => {
        process.stdout.write(JSON.stringify(message) + '\n');
      },
      close: () => {
        process.exit(0);
      },
    };

    // Extend connection with EventEmitter capabilities
    const connectionWithEvents = Object.assign(new EventEmitter(), connection);

    let buffer = '';
    process.stdin.on('data', (chunk: Buffer) => {
      buffer += chunk.toString();
      const lines = buffer.split('\n');
      buffer = lines.pop() || '';

      for (const line of lines) {
        if (line.trim()) {
          try {
            const request = JSON.parse(line) as MCPRequest;
            connectionWithEvents.emit('request', request);
          } catch (error) {
            logger.error('Failed to parse stdio message:', error);
          }
        }
      }
    });

    process.stdin.on('end', () => {
      connectionWithEvents.emit('close');
    });

    this.connections.set(id, connectionWithEvents as any);
    return connectionWithEvents as any;
  }

  private handleConnection(connection: Connection): void {
    logger.info(`New connection established: ${connection.id}`);
    this.emit('connection', connection);
  }

  async stop(): Promise<void> {
    // Close all connections
    for (const connection of this.connections.values()) {
      connection.close();
    }
    this.connections.clear();

    // Stop WebSocket server if running
    if (this.wsServer) {
      return new Promise((resolve) => {
        this.wsServer!.close(() => {
          logger.info('WebSocket server stopped');
          resolve();
        });
      });
    }
  }
}