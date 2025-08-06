/**
 * Ballerina Package Add Tool
 */

import { z } from 'zod';
import type { ToolResult } from '../../types/mcp';
import { BallerinaCLI } from '../../integration/ballerina-cli';
import { logger } from '../../utils/logger';
import * as fs from 'fs/promises';
import * as path from 'path';
import * as toml from '@iarna/toml';

export const addPackageSchema = z.object({
  projectPath: z.string(),
  packageName: z.string(), // Format: org/name
  version: z.string().optional(),
  scope: z.enum(['default', 'test', 'build']).default('default'),
});

export async function addPackage(args: z.infer<typeof addPackageSchema>): Promise<ToolResult> {
  const cli = new BallerinaCLI();
  
  try {
    // Verify project exists
    const ballerinaTomlPath = path.join(args.projectPath, 'Ballerina.toml');
    try {
      await fs.access(ballerinaTomlPath);
    } catch {
      return {
        success: false,
        error: `Not a Ballerina project: ${args.projectPath}. Missing Ballerina.toml`,
      };
    }

    // Parse package name
    const [org, name] = args.packageName.split('/');
    if (!org || !name) {
      return {
        success: false,
        error: `Invalid package name format. Use: organization/package-name`,
      };
    }

    logger.info(`Adding package ${args.packageName} to project`);

    // Read current Ballerina.toml
    const tomlContent = await fs.readFile(ballerinaTomlPath, 'utf-8');
    const config = toml.parse(tomlContent) as any;

    // Check if dependency already exists
    const dependencies = config.dependencies || [];
    const existingDep = dependencies.find((dep: any) => 
      dep.org === org && dep.name === name
    );

    if (existingDep) {
      if (existingDep.version === args.version || !args.version) {
        return {
          success: false,
          error: `Package ${args.packageName} already exists in dependencies`,
        };
      }
      // Update version if different
      existingDep.version = args.version;
    } else {
      // Add new dependency
      const newDep: any = {
        org,
        name,
      };
      
      if (args.version) {
        newDep.version = args.version;
      }
      
      if (args.scope !== 'default') {
        newDep.scope = args.scope;
      }
      
      if (!config.dependencies) {
        config.dependencies = [];
      }
      config.dependencies.push(newDep);
    }

    // Write updated Ballerina.toml
    const updatedToml = toml.stringify(config as any);
    await fs.writeFile(ballerinaTomlPath, updatedToml);

    // Pull the package using Ballerina CLI
    const packageSpec = args.version 
      ? `${args.packageName}:${args.version}`
      : args.packageName;
    
    const result = await cli.pullPackage(packageSpec);

    if (!result.success) {
      // Revert changes if pull failed
      await fs.writeFile(ballerinaTomlPath, tomlContent);
      return {
        success: false,
        error: `Failed to pull package: ${result.stderr}`,
      };
    }

    // Get updated dependencies list
    const updatedConfig = toml.parse(await fs.readFile(ballerinaTomlPath, 'utf-8')) as any;
    
    return {
      success: true,
      result: {
        packageName: args.packageName,
        version: args.version || 'latest',
        scope: args.scope,
        projectPath: args.projectPath,
        dependencies: updatedConfig.dependencies || [],
        message: `Successfully added ${args.packageName} to project`,
      },
    };
  } catch (error: any) {
    logger.error('Error adding Ballerina package:', error);
    return {
      success: false,
      error: error.message || 'Failed to add package',
    };
  }
}