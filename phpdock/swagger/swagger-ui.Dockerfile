FROM swaggerapi/swagger-ui

# Add entry script
COPY ui-entrypoint.sh /usr/local/bin/ui-entrypoint.sh
RUN chmod +x /usr/local/bin/ui-entrypoint.sh

# Use our entrypoint script to handle permissions
ENTRYPOINT ["/usr/local/bin/ui-entrypoint.sh"]