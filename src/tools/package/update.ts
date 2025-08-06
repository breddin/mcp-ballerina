/**
 * Ballerina Package Update Tool
 */

import { z } from 'zod';
import type { ToolResult } from '../../types/mcp';
import { BallerinaCLI } from '../../integration/ballerina-cli';
import { logger } from '../../utils/logger';
import * as fs from 'fs/promises';
import * as path from 'path';
import * as toml from '@iarna/toml';

export const updatePackageSchema = z.object({
  projectPath: z.string(),
  packageName: z.string().optional(), // If not specified, update all
  version: z.string().optional(), // Target version
  strategy: z.enum(['latest', 'major', 'minor', 'patch']).default('latest'),
});

export async function updatePackage(args: z.infer<typeof updatePackageSchema>): Promise<ToolResult> {
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

    logger.info(`Updating packages for project: ${args.projectPath}`);

    // Read current Ballerina.toml
    const tomlContent = await fs.readFile(ballerinaTomlPath, 'utf-8');
    const config = toml.parse(tomlContent) as any;

    if (!config.dependencies || config.dependencies.length === 0) {
      return {
        success: false,
        error: `No dependencies found in project`,
      };
    }

    const updatedPackages: any[] = [];
    const failedPackages: any[] = [];

    // Update specific package or all packages
    const packagesToUpdate = args.packageName
      ? config.dependencies.filter((dep: any) => 
          `${dep.org}/${dep.name}` === args.packageName
        )
      : config.dependencies;

    if (packagesToUpdate.length === 0) {
      return {
        success: false,
        error: `Package ${args.packageName} not found in dependencies`,
      };
    }

    // Update each package
    for (const dep of packagesToUpdate) {
      const packageFullName = `${dep.org}/${dep.name}`;
      
      try {
        // Determine target version
        let targetVersion = args.version;
        
        if (!targetVersion && args.strategy === 'latest') {
          // Get latest version from Central
          const searchResult = await cli.searchPackages(packageFullName);
          if (searchResult.success && searchResult.stdout) {
            const latestVersion = parseLatestVersion(searchResult.stdout, dep.org, dep.name);
            if (latestVersion) {
              targetVersion = latestVersion;
            }
          }
        }
        
        if (targetVersion && targetVersion !== dep.version) {
          // Update version in config
          dep.version = targetVersion;
          
          // Pull the new version
          const pullResult = await cli.pullPackage(`${packageFullName}:${targetVersion}`);
          
          if (pullResult.success) {
            updatedPackages.push({
              package: packageFullName,
              oldVersion: dep.version,
              newVersion: targetVersion,
            });
          } else {
            failedPackages.push({
              package: packageFullName,
              error: pullResult.stderr,
            });
          }
        }
      } catch (error: any) {
        failedPackages.push({
          package: packageFullName,
          error: error.message,
        });
      }
    }

    // Write updated Ballerina.toml if any packages were updated
    if (updatedPackages.length > 0) {
      const updatedToml = toml.stringify(config as any);
      await fs.writeFile(ballerinaTomlPath, updatedToml);
    }

    // Build the project to update lock file
    if (updatedPackages.length > 0) {
      logger.info('Building project to update lock file...');
      await cli.buildProject(args.projectPath, { skipTests: true });
    }

    return {
      success: failedPackages.length === 0,
      result: {
        projectPath: args.projectPath,
        updated: updatedPackages,
        failed: failedPackages,
        totalUpdated: updatedPackages.length,
        totalFailed: failedPackages.length,
        message: `Updated ${updatedPackages.length} packages` + 
                 (failedPackages.length > 0 ? `, ${failedPackages.length} failed` : ''),
      },
    };
  } catch (error: any) {
    logger.error('Error updating Ballerina packages:', error);
    return {
      success: false,
      error: error.message || 'Failed to update packages',
    };
  }
}

function parseLatestVersion(output: string, org: string, name: string): string | null {
  const lines = output.split('\n');
  const packagePattern = new RegExp(`^${org}/${name}:(\\S+)`);
  
  for (const line of lines) {
    const match = line.match(packagePattern);
    if (match) {
      return match[1];
    }
  }
  
  return null;
}