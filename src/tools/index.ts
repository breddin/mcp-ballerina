/**
 * Tool Registration
 */

import type { ToolRegistry } from './registry';
import { createNewProject, newProjectSchema } from './project/new';
import { buildProject, buildProjectSchema } from './project/build';
import { testProject, testProjectSchema } from './project/test';
import { runProject, runProjectSchema } from './project/run';
import { logger } from '../utils/logger';

export function registerAllTools(registry: ToolRegistry): void {
  logger.info('Registering Ballerina tools...');

  // Project management tools
  registry.register({
    name: 'ballerina.project.new',
    description: 'Create a new Ballerina project',
    inputSchema: {
      type: 'object',
      properties: {
        projectName: { type: 'string', description: 'Name of the project' },
        projectType: { 
          type: 'string', 
          enum: ['service', 'library', 'application'],
          description: 'Type of project'
        },
        template: { type: 'string', description: 'Template to use' },
        directory: { type: 'string', description: 'Directory to create project in' },
      },
      required: ['projectName'],
    },
    handler: createNewProject,
    schema: newProjectSchema,
  } as any);

  registry.register({
    name: 'ballerina.project.build',
    description: 'Build a Ballerina project',
    inputSchema: {
      type: 'object',
      properties: {
        projectPath: { type: 'string', description: 'Path to the project' },
        offline: { type: 'boolean', description: 'Build offline' },
        skipTests: { type: 'boolean', description: 'Skip running tests' },
        codeCoverage: { type: 'boolean', description: 'Generate code coverage' },
        cloud: { type: 'boolean', description: 'Build for cloud' },
        observabilityIncluded: { type: 'boolean', description: 'Include observability' },
      },
      required: ['projectPath'],
    },
    handler: buildProject,
    schema: buildProjectSchema,
  } as any);

  registry.register({
    name: 'ballerina.project.test',
    description: 'Run tests for a Ballerina project',
    inputSchema: {
      type: 'object',
      properties: {
        projectPath: { type: 'string', description: 'Path to the project' },
        codeCoverage: { type: 'boolean', description: 'Generate code coverage' },
        testReport: { type: 'boolean', description: 'Generate test report' },
        groups: { 
          type: 'array', 
          items: { type: 'string' },
          description: 'Test groups to run' 
        },
        disableGroups: { 
          type: 'array', 
          items: { type: 'string' },
          description: 'Test groups to disable' 
        },
        tests: { 
          type: 'array', 
          items: { type: 'string' },
          description: 'Specific tests to run' 
        },
        rerunFailed: { type: 'boolean', description: 'Rerun failed tests' },
        parallel: { type: 'boolean', description: 'Run tests in parallel' },
      },
      required: ['projectPath'],
    },
    handler: testProject,
    schema: testProjectSchema,
  } as any);

  registry.register({
    name: 'ballerina.project.run',
    description: 'Run a Ballerina project',
    inputSchema: {
      type: 'object',
      properties: {
        projectPath: { type: 'string', description: 'Path to the project' },
        arguments: { 
          type: 'array', 
          items: { type: 'string' },
          description: 'Arguments to pass to the program' 
        },
        observabilityIncluded: { type: 'boolean', description: 'Include observability' },
        offline: { type: 'boolean', description: 'Run offline' },
        debug: { type: 'number', description: 'Debug port' },
      },
      required: ['projectPath'],
    },
    handler: runProject,
    schema: runProjectSchema,
  } as any);

  logger.info(`Registered ${registry.listMethods().length} Ballerina tools`);
}