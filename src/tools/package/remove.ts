/**
 * Ballerina Package Remove Tool
 */

import { z } from 'zod';
import type { ToolResult } from '../../types/mcp';
import { logger } from '../../utils/logger';
import * as fs from 'fs/promises';
import * as path from 'path';
import * as toml from '@iarna/toml';

export const removePackageSchema = z.object({
  projectPath: z.string(),
  packageName: z.string(), // Format: org/name
});

export async function removePackage(args: z.infer<typeof removePackageSchema>): Promise<ToolResult> {
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

    logger.info(`Removing package ${args.packageName} from project`);

    // Read current Ballerina.toml
    const tomlContent = await fs.readFile(ballerinaTomlPath, 'utf-8');
    const config = toml.parse(tomlContent) as any;

    // Find and remove dependency
    if (!config.dependencies || !Array.isArray(config.dependencies)) {
      return {
        success: false,
        error: `No dependencies found in project`,
      };
    }

    const originalLength = config.dependencies.length;
    config.dependencies = config.dependencies.filter((dep: any) => 
      !(dep.org === org && dep.name === name)
    );

    if (config.dependencies.length === originalLength) {
      return {
        success: false,
        error: `Package ${args.packageName} not found in dependencies`,
      };
    }

    // Write updated Ballerina.toml
    const updatedToml = toml.stringify(config as any);
    await fs.writeFile(ballerinaTomlPath, updatedToml);

    // Clean up Dependencies.toml if it exists
    const depsTomlPath = path.join(args.projectPath, 'Dependencies.toml');
    try {
      const depsContent = await fs.readFile(depsTomlPath, 'utf-8');
      const depsConfig = toml.parse(depsContent) as any;
      
      // Remove from Dependencies.toml
      if (depsConfig.dependencies) {
        depsConfig.dependencies = depsConfig.dependencies.filter((dep: any) => 
          !(dep.org === org && dep.name === name)
        );
        await fs.writeFile(depsTomlPath, toml.stringify(depsConfig as any));
      }
    } catch {
      // Dependencies.toml might not exist, which is fine
    }

    return {
      success: true,
      result: {
        packageName: args.packageName,
        projectPath: args.projectPath,
        remainingDependencies: config.dependencies,
        message: `Successfully removed ${args.packageName} from project`,
      },
    };
  } catch (error: any) {
    logger.error('Error removing Ballerina package:', error);
    return {
      success: false,
      error: error.message || 'Failed to remove package',
    };
  }
}