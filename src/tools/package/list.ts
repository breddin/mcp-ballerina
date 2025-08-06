/**
 * Ballerina Package List Tool
 */

import { z } from 'zod';
import type { ToolResult } from '../../types/mcp';
import { logger } from '../../utils/logger';
import * as fs from 'fs/promises';
import * as path from 'path';
import * as toml from '@iarna/toml';

export const listPackagesSchema = z.object({
  projectPath: z.string(),
  includeTransitive: z.boolean().default(false),
  scope: z.enum(['all', 'default', 'test', 'build']).default('all'),
});

interface PackageInfo {
  org: string;
  name: string;
  version: string;
  scope?: string;
  transitive?: boolean;
}

export async function listPackages(args: z.infer<typeof listPackagesSchema>): Promise<ToolResult> {
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

    logger.info(`Listing packages for project: ${args.projectPath}`);

    // Read Ballerina.toml for direct dependencies
    const tomlContent = await fs.readFile(ballerinaTomlPath, 'utf-8');
    const config = toml.parse(tomlContent) as any;
    
    const directDependencies: PackageInfo[] = [];
    
    if (config.dependencies && Array.isArray(config.dependencies)) {
      for (const dep of config.dependencies) {
        const depScope = dep.scope || 'default';
        
        // Filter by scope if specified
        if (args.scope === 'all' || args.scope === depScope) {
          directDependencies.push({
            org: dep.org,
            name: dep.name,
            version: dep.version || 'latest',
            scope: depScope,
            transitive: false,
          });
        }
      }
    }

    let allDependencies = [...directDependencies];

    // Include transitive dependencies if requested
    if (args.includeTransitive) {
      const transitiveDeps = await getTransitiveDependencies(args.projectPath, args.scope);
      allDependencies = [...allDependencies, ...transitiveDeps];
    }

    // Group dependencies by scope
    const grouped: Record<string, PackageInfo[]> = {};
    for (const dep of allDependencies) {
      const scope = dep.scope || 'default';
      if (!grouped[scope]) {
        grouped[scope] = [];
      }
      grouped[scope].push(dep);
    }

    // Get project info
    const projectInfo = {
      name: config.package?.name || 'unknown',
      org: config.package?.org || 'unknown',
      version: config.package?.version || '0.1.0',
    };

    return {
      success: true,
      result: {
        project: projectInfo,
        totalDependencies: allDependencies.length,
        directDependencies: directDependencies.length,
        transitiveDependencies: allDependencies.length - directDependencies.length,
        dependencies: args.scope === 'all' ? grouped : allDependencies,
        message: `Found ${allDependencies.length} dependencies (${directDependencies.length} direct)`,
      },
    };
  } catch (error: any) {
    logger.error('Error listing Ballerina packages:', error);
    return {
      success: false,
      error: error.message || 'Failed to list packages',
    };
  }
}

async function getTransitiveDependencies(
  projectPath: string, 
  scope: string
): Promise<PackageInfo[]> {
  const transitiveDeps: PackageInfo[] = [];
  
  try {
    // Read Dependencies.toml for transitive dependencies
    const depsTomlPath = path.join(projectPath, 'Dependencies.toml');
    const depsContent = await fs.readFile(depsTomlPath, 'utf-8');
    const depsConfig = toml.parse(depsContent) as any;
    
    if (depsConfig.dependencies && Array.isArray(depsConfig.dependencies)) {
      for (const dep of depsConfig.dependencies) {
        const depScope = dep.scope || 'default';
        
        // Filter by scope and mark as transitive
        if (scope === 'all' || scope === depScope) {
          // Check if it's actually transitive (not in direct deps)
          const isTransitive = dep.transitive !== false;
          
          if (isTransitive) {
            transitiveDeps.push({
              org: dep.org,
              name: dep.name,
              version: dep.version || 'unknown',
              scope: depScope,
              transitive: true,
            });
          }
        }
      }
    }
  } catch (error) {
    // Dependencies.toml might not exist or be readable
    logger.debug('Could not read Dependencies.toml:', error);
  }
  
  return transitiveDeps;
}