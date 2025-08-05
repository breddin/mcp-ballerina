/**
 * Session Manager - Manages client sessions
 */

import { randomUUID } from 'crypto';
import type { Session, Connection, SessionContext, SessionState } from '../types/mcp';
import { logger } from '../utils/logger';

export class SessionManager {
  private sessions: Map<string, Session> = new Map();

  create(connection: Connection): Session {
    const sessionId = randomUUID();
    
    const session: Session = {
      id: sessionId,
      connection,
      state: 'uninitialized' as SessionState,
      context: {
        initialized: false,
        capabilities: {},
      } as SessionContext,
      permissions: this.determinePermissions(connection),
    };

    this.sessions.set(sessionId, session);
    logger.info(`Session created: ${sessionId}`);
    
    return session;
  }

  get(id: string): Session | undefined {
    return this.sessions.get(id);
  }

  destroy(id: string): void {
    const session = this.sessions.get(id);
    if (session) {
      // Clean up session resources
      this.cleanup(session);
      this.sessions.delete(id);
      logger.info(`Session destroyed: ${id}`);
    }
  }

  destroyAll(): void {
    for (const session of this.sessions.values()) {
      this.cleanup(session);
    }
    this.sessions.clear();
    logger.info('All sessions destroyed');
  }

  private cleanup(session: Session): void {
    // Perform any necessary cleanup
    session.state = 'shutdown' as SessionState;
    
    // Close connection if still open
    try {
      session.connection.close();
    } catch (error) {
      logger.error(`Error closing connection for session ${session.id}:`, error);
    }
  }

  private determinePermissions(connection: Connection): string[] {
    // TODO: Implement permission determination based on authentication
    // For now, grant all permissions
    return ['tools:*', 'resources:*', 'prompts:*'];
  }

  getActiveSessions(): number {
    return this.sessions.size;
  }

  getSessionInfo(id: string): object | null {
    const session = this.sessions.get(id);
    if (!session) return null;

    return {
      id: session.id,
      state: session.state,
      transport: session.connection.transport,
      initialized: session.context.initialized,
      clientInfo: session.context.clientInfo,
      permissions: session.permissions,
    };
  }
}