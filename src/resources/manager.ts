/**
 * Resource Manager - Manages MCP resources
 */

import type { Resource, ResourceContent } from '../types/mcp';
import { logger } from '../utils/logger';

export interface ResourceProvider {
  list(filter?: any): Promise<Resource[]>;
  read(uri: string): Promise<ResourceContent>;
  write?(uri: string, content: any): Promise<boolean>;
  watch?(uri: string, callback: (event: any) => void): () => void;
}

export class ResourceManager {
  private providers: Map<string, ResourceProvider> = new Map();

  addProvider(scheme: string, provider: ResourceProvider): void {
    this.providers.set(scheme, provider);
    logger.info(`Registered resource provider for scheme: ${scheme}`);
  }

  async list(filter?: any): Promise<Resource[]> {
    const allResources: Resource[] = [];
    
    for (const [scheme, provider] of this.providers) {
      try {
        const resources = await provider.list(filter);
        allResources.push(...resources);
      } catch (error) {
        logger.error(`Error listing resources from ${scheme}:`, error);
      }
    }
    
    return allResources;
  }

  async read(uri: string): Promise<ResourceContent> {
    const scheme = this.extractScheme(uri);
    const provider = this.providers.get(scheme);
    
    if (!provider) {
      throw new Error(`No provider for scheme: ${scheme}`);
    }
    
    return provider.read(uri);
  }

  async write(uri: string, content: any): Promise<boolean> {
    const scheme = this.extractScheme(uri);
    const provider = this.providers.get(scheme);
    
    if (!provider || !provider.write) {
      throw new Error(`Write not supported for scheme: ${scheme}`);
    }
    
    return provider.write(uri, content);
  }

  watch(uri: string, callback: (event: any) => void): () => void {
    const scheme = this.extractScheme(uri);
    const provider = this.providers.get(scheme);
    
    if (!provider || !provider.watch) {
      throw new Error(`Watch not supported for scheme: ${scheme}`);
    }
    
    return provider.watch(uri, callback);
  }

  private extractScheme(uri: string): string {
    const match = uri.match(/^([a-z]+):\/\//);
    return match ? match[1] : 'file';
  }
}