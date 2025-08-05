/**
 * Prompt Handler - Manages prompt templates
 */

import type { PromptTemplate } from '../types/mcp';
import { logger } from '../utils/logger';

export class PromptHandler {
  private prompts: Map<string, PromptTemplate> = new Map();

  constructor() {
    this.loadBuiltInPrompts();
  }

  private loadBuiltInPrompts(): void {
    // Load built-in Ballerina prompts
    const builtInPrompts: PromptTemplate[] = [
      {
        id: 'ballerina.project.init',
        name: 'Initialize Ballerina Project',
        description: 'Create a new Ballerina project with customization options',
        arguments: [
          {
            name: 'projectName',
            description: 'Name of the project',
            required: true,
          },
          {
            name: 'projectType',
            description: 'Type of project (service, library, application)',
            required: true,
            default: 'service',
          },
        ],
        template: 'Create a new Ballerina {projectType} project named {projectName}',
      },
      {
        id: 'ballerina.error.diagnose',
        name: 'Diagnose Build Error',
        description: 'Help diagnose and fix Ballerina build errors',
        arguments: [
          {
            name: 'error',
            description: 'The error message',
            required: true,
          },
          {
            name: 'file',
            description: 'The file where error occurred',
            required: false,
          },
        ],
        template: 'Help me fix this Ballerina error: {error} in file {file}',
      },
    ];

    for (const prompt of builtInPrompts) {
      this.prompts.set(prompt.id, prompt);
    }
    
    logger.info(`Loaded ${builtInPrompts.length} built-in prompts`);
  }

  async list(): Promise<PromptTemplate[]> {
    return Array.from(this.prompts.values());
  }

  async get(id: string): Promise<PromptTemplate | null> {
    return this.prompts.get(id) || null;
  }

  async render(id: string, args: Record<string, any>): Promise<string> {
    const prompt = this.prompts.get(id);
    
    if (!prompt) {
      throw new Error(`Prompt not found: ${id}`);
    }
    
    let result = prompt.template;
    
    for (const [key, value] of Object.entries(args)) {
      result = result.replace(new RegExp(`\\{${key}\\}`, 'g'), String(value));
    }
    
    return result;
  }

  addPrompt(prompt: PromptTemplate): void {
    this.prompts.set(prompt.id, prompt);
    logger.info(`Added prompt: ${prompt.id}`);
  }
}