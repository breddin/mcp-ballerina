/**
 * Jest Test Setup
 */

// Extend Jest matchers if needed
expect.extend({
  toBeValidMCPResponse(received: any) {
    const pass = 
      received &&
      typeof received === 'object' &&
      received.jsonrpc === '2.0' &&
      (received.id !== undefined) &&
      (received.result !== undefined || received.error !== undefined);

    return {
      pass,
      message: () => 
        pass
          ? `Expected ${JSON.stringify(received)} not to be a valid MCP response`
          : `Expected ${JSON.stringify(received)} to be a valid MCP response`,
    };
  },
});

// Global test timeout
jest.setTimeout(30000);

// Mock console methods to reduce noise in tests
global.console = {
  ...console,
  log: jest.fn(),
  debug: jest.fn(),
  info: jest.fn(),
  // Keep warn and error for debugging
  warn: console.warn,
  error: console.error,
};