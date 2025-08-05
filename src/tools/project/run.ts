/**
 * Ballerina Project Run Tool
 */

import { z } from 'zod';
import type { ToolResult } from '../../types/mcp';
import { BallerinaCLI } from '../../integration/ballerina-cli';
import { logger } from '../../utils/logger';
import * as path from 'path';
import * as fs from 'fs/promises';

export const runProjectSchema = z.object({
  projectPath: z.string(),
  arguments: z.array(z.string()).optional(),
  observabilityIncluded: z.boolean().default(false),
  offline: z.boolean().default(false),
  debug: z.number().optional(), // Debug port
});

export async function runProject(args: z.infer<typeof runProjectSchema>): Promise<ToolResult> {
  const cli = new BallerinaCLI();
  
  try {
    // Verify project exists
    const ballerinaToml = path.join(args.projectPath, 'Ballerina.toml');
    try {
      await fs.access(ballerinaToml);
    } catch {
      return {
        success: false,
        error: `Not a Ballerina project: ${args.projectPath}. Missing Ballerina.toml`,
      };
    }

    logger.info(`Running Ballerina project: ${args.projectPath}`);

    // Build command arguments
    const runArgs: string[] = [];
    
    if (args.observabilityIncluded) runArgs.push('--observability-included');
    if (args.offline) runArgs.push('--offline');
    if (args.debug) runArgs.push('--debug', args.debug.toString());
    
    // Add user arguments
    if (args.arguments && args.arguments.length > 0) {
      runArgs.push('--', ...args.arguments);
    }

    // Run the project
    const result = await cli.execute('run', runArgs, { 
      cwd: args.projectPath,
      timeout: 60000, // 1 minute timeout for run
    });

    if (!result.success) {
      return {
        success: false,
        error: 'Failed to run project',
        result: {
          exitCode: result.exitCode,
          output: result.stderr || result.stdout,
        },
      };
    }

    return {
      success: true,
      result: {
        projectPath: args.projectPath,
        exitCode: result.exitCode,
        output: result.stdout,
        duration: result.duration,
        message: 'Project executed successfully',
      },
    };
  } catch (error: any) {
    logger.error('Error running Ballerina project:', error);
    return {
      success: false,
      error: error.message || 'Unknown error occurred',
    };
  }
}