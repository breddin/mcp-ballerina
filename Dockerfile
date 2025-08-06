# Multi-stage build for MCP Ballerina Server
# Stage 1: Build stage
FROM ballerina/ballerina:2201.12.7 AS builder

# Set working directory
WORKDIR /app

# Create non-root user for build
RUN groupadd -r ballerina && useradd -r -g ballerina ballerina

# Copy build configuration files
COPY Ballerina.toml ./
COPY package.json ./

# Copy source code
COPY modules/ ./modules/
COPY mcp_ballerina_server.bal ./
COPY mcp_ballerina_server_enhanced.bal ./

# Set ownership for build user
RUN chown -R ballerina:ballerina /app

# Switch to non-root user
USER ballerina

# Build the application
RUN bal build

# Stage 2: Runtime stage
FROM ballerina/ballerina-runtime:2201.12.7-slim

# Install security updates and required packages
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        dumb-init && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create non-root user for runtime
RUN groupadd -r ballerina && \
    useradd -r -g ballerina -d /app -s /sbin/nologin ballerina && \
    mkdir -p /app/logs /app/data && \
    chown -R ballerina:ballerina /app

# Set working directory
WORKDIR /app

# Copy built application from builder stage
COPY --from=builder --chown=ballerina:ballerina /app/target/bin/*.jar ./
COPY --from=builder --chown=ballerina:ballerina /app/target/cache/ ./cache/
COPY --from=builder --chown=ballerina:ballerina /app/Ballerina.toml ./

# Create config and data directories
RUN mkdir -p /app/config /app/logs /app/data && \
    chown -R ballerina:ballerina /app

# Switch to non-root user
USER ballerina

# Expose ports
EXPOSE 8080 8443 9090

# Environment variables
ENV BALLERINA_HOME=/ballerina/runtime \
    PATH=${BALLERINA_HOME}/bin:$PATH \
    MCP_SERVER_PORT=8080 \
    MCP_METRICS_PORT=9090 \
    LOG_LEVEL=INFO \
    JVM_HEAP_SIZE=512m

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

# Use dumb-init for proper signal handling
ENTRYPOINT ["/usr/bin/dumb-init", "--"]

# Default command
CMD ["bal", "run", "mcp_ballerina_server_enhanced.jar", "--", \
     "--port=${MCP_SERVER_PORT}", \
     "--metrics-port=${MCP_METRICS_PORT}", \
     "--log-level=${LOG_LEVEL}"]

# Labels for metadata
LABEL maintainer="bennettreddin" \
      version="0.1.0" \
      description="MCP Ballerina Server with Language Server Protocol support" \
      org.opencontainers.image.source="https://github.com/bennettreddin/mcp-ballerina" \
      org.opencontainers.image.documentation="https://github.com/bennettreddin/mcp-ballerina/README.md" \
      org.opencontainers.image.licenses="MIT"