/**
 * Ballerina Project Test Tool
 */

import { z } from 'zod';
import type { ToolResult } from '../../types/mcp';
import { BallerinaCLI } from '../../integration/ballerina-cli';
import { logger } from '../../utils/logger';
import * as fs from 'fs/promises';
import * as path from 'path';

export const testProjectSchema = z.object({
  projectPath: z.string(),
  codeCoverage: z.boolean().default(false),
  testReport: z.boolean().default(false),
  groups: z.array(z.string()).optional(),
  disableGroups: z.array(z.string()).optional(),
  tests: z.array(z.string()).optional(),
  rerunFailed: z.boolean().default(false),
  parallel: z.boolean().default(true),
});

export async function testProject(args: z.infer<typeof testProjectSchema>): Promise<ToolResult> {
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

    logger.info(`Running tests for Ballerina project: ${args.projectPath}`);

    // Build command arguments
    const testArgs: string[] = [];
    
    if (args.codeCoverage) testArgs.push('--code-coverage');
    if (args.testReport) testArgs.push('--test-report');
    if (!args.parallel) testArgs.push('--disable-parallel');
    if (args.rerunFailed) testArgs.push('--rerun-failed');
    
    if (args.groups && args.groups.length > 0) {
      testArgs.push('--groups', args.groups.join(','));
    }
    
    if (args.disableGroups && args.disableGroups.length > 0) {
      testArgs.push('--disable-groups', args.disableGroups.join(','));
    }
    
    if (args.tests && args.tests.length > 0) {
      testArgs.push('--tests', args.tests.join(','));
    }

    // Run tests
    const result = await cli.execute('test', testArgs, { 
      cwd: args.projectPath,
      timeout: 120000, // 2 minutes for tests
    });

    // Parse test results
    const testResults = parseDetailedTestResults(result.stdout);
    
    // Check for test failures
    if (!result.success && testResults.failed > 0) {
      return {
        success: false,
        error: 'Tests failed',
        result: {
          ...testResults,
          output: result.stdout,
          errors: parseTestErrors(result.stderr),
        },
      };
    }

    // Get coverage report if generated
    let coverage = null;
    if (args.codeCoverage) {
      coverage = await getCoverageDetails(args.projectPath);
    }

    // Get test report if generated
    let testReport = null;
    if (args.testReport) {
      testReport = await getTestReportPath(args.projectPath);
    }

    return {
      success: true,
      result: {
        projectPath: args.projectPath,
        ...testResults,
        coverage,
        testReport,
        duration: result.duration,
        message: `Tests completed: ${testResults.passed} passed, ${testResults.failed} failed, ${testResults.skipped} skipped`,
        output: result.stdout,
      },
    };
  } catch (error: any) {
    logger.error('Error running Ballerina tests:', error);
    return {
      success: false,
      error: error.message || 'Unknown error occurred',
    };
  }
}

function parseDetailedTestResults(stdout: string): any {
  const results = {
    passed: 0,
    failed: 0,
    skipped: 0,
    total: 0,
    modules: [] as any[],
    failedTests: [] as any[],
  };

  const lines = stdout.split('\n');
  
  // Parse module test results
  const modulePattern = /\s+(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/;
  let inModuleSection = false;
  
  for (const line of lines) {
    if (line.includes('MODULE') && line.includes('TOTAL')) {
      inModuleSection = true;
      continue;
    }
    
    if (inModuleSection && line.trim() === '') {
      inModuleSection = false;
    }
    
    if (inModuleSection) {
      const match = line.match(modulePattern);
      if (match) {
        const module = {
          name: match[1],
          total: parseInt(match[2], 10),
          passed: parseInt(match[3], 10),
          failed: parseInt(match[4], 10),
          skipped: parseInt(match[5], 10),
        };
        results.modules.push(module);
      }
    }
    
    // Parse failed test details
    if (line.includes('[fail]')) {
      const testMatch = line.match(/\[fail\]\s+(\S+):(\S+)/);
      if (testMatch) {
        results.failedTests.push({
          module: testMatch[1],
          test: testMatch[2],
        });
      }
    }
  }
  
  // Parse summary
  const summaryPattern = /(\d+)\s+passing/;
  const failedPattern = /(\d+)\s+failing/;
  const skippedPattern = /(\d+)\s+skipped/;
  
  const passMatch = stdout.match(summaryPattern);
  const failMatch = stdout.match(failedPattern);
  const skipMatch = stdout.match(skippedPattern);
  
  if (passMatch) results.passed = parseInt(passMatch[1], 10);
  if (failMatch) results.failed = parseInt(failMatch[1], 10);
  if (skipMatch) results.skipped = parseInt(skipMatch[1], 10);
  
  results.total = results.passed + results.failed + results.skipped;
  
  return results;
}

function parseTestErrors(stderr: string): string[] {
  const errors: string[] = [];
  const lines = stderr.split('\n');
  
  for (const line of lines) {
    if (line.includes('ERROR') || line.includes('FAIL')) {
      errors.push(line.trim());
    }
  }
  
  return errors;
}

async function getCoverageDetails(projectPath: string): Promise<any> {
  try {
    const coverageJsonPath = path.join(projectPath, 'target', 'report', 'coverage', 'coverage.json');
    const coverageHtmlPath = path.join(projectPath, 'target', 'report', 'coverage', 'index.html');
    
    // Check if coverage files exist
    const hasJson = await fs.access(coverageJsonPath).then(() => true).catch(() => false);
    const hasHtml = await fs.access(coverageHtmlPath).then(() => true).catch(() => false);
    
    if (hasJson) {
      // Parse JSON coverage report
      const coverageData = await fs.readFile(coverageJsonPath, 'utf-8');
      const coverage = JSON.parse(coverageData);
      
      return {
        summary: coverage.summary || {},
        reportPath: path.relative(projectPath, coverageHtmlPath),
        jsonPath: path.relative(projectPath, coverageJsonPath),
      };
    } else if (hasHtml) {
      return {
        reportPath: path.relative(projectPath, coverageHtmlPath),
        available: true,
      };
    }
  } catch (error) {
    logger.warn('Could not parse coverage report:', error);
  }
  
  return null;
}

async function getTestReportPath(projectPath: string): Promise<string | null> {
  try {
    const reportPath = path.join(projectPath, 'target', 'report', 'test_results.html');
    await fs.access(reportPath);
    return path.relative(projectPath, reportPath);
  } catch {
    return null;
  }
}