/**
 * Ballerina Project Creation Tool
 */

import { z } from 'zod';
import type { ToolResult } from '../../types/mcp';
import { BallerinaCLI } from '../../integration/ballerina-cli';
import { logger } from '../../utils/logger';
import * as fs from 'fs/promises';
import * as path from 'path';

export const newProjectSchema = z.object({
  projectName: z.string().min(1),
  projectType: z.enum(['service', 'library', 'application']).default('service'),
  template: z.string().optional(),
  directory: z.string().optional(),
});

export async function createNewProject(args: z.infer<typeof newProjectSchema>): Promise<ToolResult> {
  const cli = new BallerinaCLI();
  
  try {
    // Check if Ballerina is installed
    const isInstalled = await cli.checkInstallation();
    if (!isInstalled) {
      return {
        success: false,
        error: 'Ballerina is not installed or not in PATH',
      };
    }

    // Determine project path
    const projectPath = args.directory 
      ? path.join(args.directory, args.projectName)
      : args.projectName;

    // Check if project already exists
    try {
      await fs.access(projectPath);
      return {
        success: false,
        error: `Project directory already exists: ${projectPath}`,
      };
    } catch {
      // Directory doesn't exist, which is good
    }

    // Create the project
    const result = await cli.createProject(
      args.projectName,
      args.template || args.projectType
    );

    if (!result.success) {
      return {
        success: false,
        error: result.stderr || 'Failed to create project',
      };
    }

    // List created files
    const files = await listProjectFiles(projectPath);

    logger.info(`Created Ballerina project: ${args.projectName}`);

    return {
      success: true,
      result: {
        projectName: args.projectName,
        projectPath,
        projectType: args.projectType,
        files,
        message: `Successfully created ${args.projectType} project: ${args.projectName}`,
      },
    };
  } catch (error: any) {
    logger.error('Error creating Ballerina project:', error);
    return {
      success: false,
      error: error.message || 'Unknown error occurred',
    };
  }
}

async function listProjectFiles(projectPath: string): Promise<string[]> {
  try {
    const files: string[] = [];
    
    async function scanDir(dir: string): Promise<void> {
      const entries = await fs.readdir(dir, { withFileTypes: true });
      
      for (const entry of entries) {
        const fullPath = path.join(dir, entry.name);
        const relativePath = path.relative(projectPath, fullPath);
        
        if (entry.isDirectory()) {
          await scanDir(fullPath);
        } else {
          files.push(relativePath);
        }
      }
    }
    
    await scanDir(projectPath);
    return files;
  } catch (error) {
    logger.error('Error listing project files:', error);
    return [];
  }
}