/**
 * Ballerina CLI Integration
 */

import { execa, ExecaError } from 'execa';
import { logger } from '../utils/logger';
import { config } from '../config';

export interface ExecutionResult {
  success: boolean;
  exitCode: number;
  stdout: string;
  stderr: string;
  duration: number;
}

export class BallerinaCLI {
  private ballerinaPath: string = 'bal';
  private env: NodeJS.ProcessEnv;

  constructor() {
    this.env = {
      ...process.env,
      BAL_HOME: config.ballerinaHome || process.env.BAL_HOME,
      JAVA_HOME: config.javaHome || process.env.JAVA_HOME,
    };
  }

  async execute(command: string, args: string[] = [], options: any = {}): Promise<ExecutionResult> {
    const startTime = Date.now();
    
    try {
      logger.debug(`Executing: bal ${command} ${args.join(' ')}`);
      
      const result = await execa(this.ballerinaPath, [command, ...args], {
        env: this.env,
        cwd: options.cwd,
        timeout: options.timeout || config.requestTimeout,
        ...options,
      });

      const duration = Date.now() - startTime;
      
      return {
        success: true,
        exitCode: result.exitCode || 0,
        stdout: result.stdout,
        stderr: result.stderr,
        duration,
      };
    } catch (error: any) {
      const duration = Date.now() - startTime;
      const execaError = error as ExecaError;
      
      logger.error(`Ballerina CLI error:`, {
        command,
        args,
        exitCode: execaError.exitCode,
        stderr: execaError.stderr,
      });

      return {
        success: false,
        exitCode: execaError.exitCode || 1,
        stdout: execaError.stdout || '',
        stderr: execaError.stderr || error.message,
        duration,
      };
    }
  }

  async checkInstallation(): Promise<boolean> {
    try {
      const result = await this.execute('version');
      logger.info(`Ballerina version: ${result.stdout}`);
      return result.success;
    } catch (error) {
      logger.error('Ballerina not found or not properly installed');
      return false;
    }
  }

  async createProject(name: string, type: string = 'service'): Promise<ExecutionResult> {
    return this.execute('new', [name, '--template', type]);
  }

  async buildProject(projectPath: string, options: any = {}): Promise<ExecutionResult> {
    const args: string[] = [];
    
    if (options.offline) args.push('--offline');
    if (options.skipTests) args.push('--skip-tests');
    if (options.codeCoverage) args.push('--code-coverage');
    
    return this.execute('build', args, { cwd: projectPath });
  }

  async runTests(projectPath: string, options: any = {}): Promise<ExecutionResult> {
    const args: string[] = [];
    
    if (options.codeCoverage) args.push('--code-coverage');
    if (options.testReport) args.push('--test-report');
    
    return this.execute('test', args, { cwd: projectPath });
  }

  async runProject(projectPath: string, args: string[] = []): Promise<ExecutionResult> {
    return this.execute('run', args, { cwd: projectPath });
  }

  async searchPackages(query: string): Promise<ExecutionResult> {
    return this.execute('search', [query]);
  }

  async pullPackage(packageName: string): Promise<ExecutionResult> {
    return this.execute('pull', [packageName]);
  }
}