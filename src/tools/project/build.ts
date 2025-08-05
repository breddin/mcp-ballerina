/**
 * Ballerina Project Build Tool
 */

import { z } from 'zod';
import type { ToolResult } from '../../types/mcp';
import { BallerinaCLI } from '../../integration/ballerina-cli';
import { logger } from '../../utils/logger';
import * as fs from 'fs/promises';
import * as path from 'path';

export const buildProjectSchema = z.object({
  projectPath: z.string(),
  offline: z.boolean().default(false),
  skipTests: z.boolean().default(false),
  codeCoverage: z.boolean().default(false),
  cloud: z.boolean().default(false),
  observabilityIncluded: z.boolean().default(false),
});

export async function buildProject(args: z.infer<typeof buildProjectSchema>): Promise<ToolResult> {
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

    logger.info(`Building Ballerina project: ${args.projectPath}`);

    // Build the project
    const result = await cli.buildProject(args.projectPath, {
      offline: args.offline,
      skipTests: args.skipTests,
      codeCoverage: args.codeCoverage,
    });

    if (!result.success) {
      // Parse build errors
      const errors = parseBuildErrors(result.stderr);
      return {
        success: false,
        error: 'Build failed',
        result: {
          errors,
          output: result.stderr,
        },
      };
    }

    // Find build artifacts
    const artifacts = await findBuildArtifacts(args.projectPath);
    
    // Parse test results if tests were run
    let testResults = null;
    if (!args.skipTests) {
      testResults = parseTestResults(result.stdout);
    }

    // Parse coverage if enabled
    let coverage = null;
    if (args.codeCoverage) {
      coverage = await parseCoverageReport(args.projectPath);
    }

    return {
      success: true,
      result: {
        projectPath: args.projectPath,
        artifacts,
        testResults,
        coverage,
        buildTime: result.duration,
        message: 'Build completed successfully',
        output: result.stdout,
      },
    };
  } catch (error: any) {
    logger.error('Error building Ballerina project:', error);
    return {
      success: false,
      error: error.message || 'Unknown error occurred',
    };
  }
}

function parseBuildErrors(stderr: string): any[] {
  const errors: any[] = [];
  const lines = stderr.split('\n');
  
  const errorPattern = /ERROR \[([^\]]+)\] \((\d+):(\d+)\) (.+)/;
  
  for (const line of lines) {
    const match = line.match(errorPattern);
    if (match) {
      errors.push({
        file: match[1],
        line: parseInt(match[2], 10),
        column: parseInt(match[3], 10),
        message: match[4],
      });
    }
  }
  
  return errors;
}

function parseTestResults(stdout: string): any {
  const results = {
    passed: 0,
    failed: 0,
    skipped: 0,
    total: 0,
  };
  
  const testPattern = /(\d+) passing.*?(\d+) failing.*?(\d+) skipped/;
  const match = stdout.match(testPattern);
  
  if (match) {
    results.passed = parseInt(match[1], 10);
    results.failed = parseInt(match[2], 10);
    results.skipped = parseInt(match[3], 10);
    results.total = results.passed + results.failed + results.skipped;
  }
  
  return results;
}

async function findBuildArtifacts(projectPath: string): Promise<string[]> {
  const artifacts: string[] = [];
  const targetDir = path.join(projectPath, 'target');
  
  try {
    const entries = await fs.readdir(targetDir, { recursive: true, withFileTypes: true });
    
    for (const entry of entries) {
      if (entry.isFile() && (entry.name.endsWith('.jar') || entry.name.endsWith('.bala'))) {
        const fullPath = path.join(entry.path || targetDir, entry.name);
        artifacts.push(path.relative(projectPath, fullPath));
      }
    }
  } catch (error) {
    logger.warn('Could not find build artifacts:', error);
  }
  
  return artifacts;
}

async function parseCoverageReport(projectPath: string): Promise<any> {
  try {
    const coveragePath = path.join(projectPath, 'target', 'report', 'coverage', 'index.html');
    await fs.access(coveragePath);
    
    // Basic coverage info - in real implementation, parse the HTML or JSON report
    return {
      reportPath: path.relative(projectPath, coveragePath),
      available: true,
    };
  } catch {
    return null;
  }
}