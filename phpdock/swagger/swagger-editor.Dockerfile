FROM swaggerapi/swagger-editor

# Add initialization script
COPY init-swagger.sh /usr/local/bin/init-swagger.sh
RUN chmod +x /usr/local/bin/init-swagger.sh

# Create a non-root user with configurable ID
RUN addgroup --system --gid 1000 appuser && \
    adduser --system --uid 1000 --ingroup appuser appuser

# Modify entrypoint to run our script first and fix permissions
ENTRYPOINT ["/bin/sh", "-c", "/usr/local/bin/init-swagger.sh && chown -R appuser:appuser /swagger-editor && /docker-entrypoint.sh 'nginx' '-g' 'daemon off;'"]