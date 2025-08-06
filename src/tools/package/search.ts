/**
 * Ballerina Package Search Tool
 */

import { z } from 'zod';
import type { ToolResult } from '../../types/mcp';
import { BallerinaCLI } from '../../integration/ballerina-cli';
import { logger } from '../../utils/logger';
import fetch from 'node-fetch';

export const searchPackagesSchema = z.object({
  query: z.string().min(1),
  organization: z.string().optional(),
  limit: z.number().min(1).max(100).default(10),
  offset: z.number().min(0).default(0),
});

interface BallerinaPackage {
  organization: string;
  name: string;
  version: string;
  description: string;
  balaVersion: string;
  platform: string;
  languageVersion: string;
  createdDate: string;
  url: string;
}

export async function searchPackages(args: z.infer<typeof searchPackagesSchema>): Promise<ToolResult> {
  const cli = new BallerinaCLI();
  
  try {
    logger.info(`Searching for Ballerina packages: ${args.query}`);

    // First try using Ballerina CLI
    const cliResult = await cli.searchPackages(args.query);
    
    if (cliResult.success && cliResult.stdout) {
      const packages = parseSearchOutput(cliResult.stdout);
      
      // Filter by organization if specified
      let filteredPackages = packages;
      if (args.organization) {
        filteredPackages = packages.filter(pkg => 
          pkg.organization.toLowerCase() === args.organization!.toLowerCase()
        );
      }
      
      // Apply pagination
      const paginatedPackages = filteredPackages.slice(
        args.offset,
        args.offset + args.limit
      );
      
      return {
        success: true,
        result: {
          query: args.query,
          totalResults: filteredPackages.length,
          packages: paginatedPackages,
          offset: args.offset,
          limit: args.limit,
          message: `Found ${filteredPackages.length} packages matching "${args.query}"`,
        },
      };
    }

    // Fallback to Ballerina Central API if CLI fails
    const apiPackages = await searchCentralAPI(args);
    
    return {
      success: true,
      result: {
        query: args.query,
        totalResults: apiPackages.length,
        packages: apiPackages,
        offset: args.offset,
        limit: args.limit,
        message: `Found ${apiPackages.length} packages via Central API`,
      },
    };
  } catch (error: any) {
    logger.error('Error searching Ballerina packages:', error);
    return {
      success: false,
      error: error.message || 'Failed to search packages',
    };
  }
}

function parseSearchOutput(output: string): BallerinaPackage[] {
  const packages: BallerinaPackage[] = [];
  const lines = output.split('\n');
  
  // Parse table output from bal search
  // Format: ORG/NAME:VERSION
  const packagePattern = /^([^\/]+)\/([^:]+):(\S+)/;
  
  for (const line of lines) {
    const match = line.match(packagePattern);
    if (match) {
      packages.push({
        organization: match[1],
        name: match[2],
        version: match[3],
        description: '', // CLI doesn't provide description
        balaVersion: '',
        platform: 'any',
        languageVersion: '',
        createdDate: '',
        url: `https://central.ballerina.io/${match[1]}/${match[2]}`,
      });
    }
  }
  
  return packages;
}

async function searchCentralAPI(args: z.infer<typeof searchPackagesSchema>): Promise<BallerinaPackage[]> {
  try {
    // Ballerina Central API endpoint
    const baseUrl = 'https://api.central.ballerina.io/2.0/registry/packages';
    const params = new URLSearchParams({
      q: args.query,
      limit: args.limit.toString(),
      offset: args.offset.toString(),
    });
    
    if (args.organization) {
      params.append('org', args.organization);
    }
    
    const response = await fetch(`${baseUrl}?${params}`, {
      headers: {
        'Accept': 'application/json',
      },
    });
    
    if (!response.ok) {
      throw new Error(`Central API returned ${response.status}`);
    }
    
    const data = await response.json() as any;
    
    return (data.packages || []).map((pkg: any) => ({
      organization: pkg.organization || pkg.org,
      name: pkg.name,
      version: pkg.version,
      description: pkg.description || '',
      balaVersion: pkg.balaVersion || '',
      platform: pkg.platform || 'any',
      languageVersion: pkg.ballerinaVersion || '',
      createdDate: pkg.createdDate || '',
      url: pkg.url || `https://central.ballerina.io/${pkg.organization}/${pkg.name}`,
    }));
  } catch (error) {
    logger.warn('Failed to search Central API:', error);
    return [];
  }
}