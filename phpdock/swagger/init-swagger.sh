#!/bin/sh
set -e

# Create directory if it doesn't exist
mkdir -p /swagger-editor
chmod 777 /swagger-editor

# Create a default OpenAPI file if it doesn't exist
if [ ! -f /swagger-editor/openapi.yaml ]; then
    echo "Creating default OpenAPI specification..."
    cat > /swagger-editor/openapi.yaml << 'EOL'
openapi: 3.0.0
info:
  title: API Documentation
  description: Documentation for the RESTful API
  version: 1.0.0
servers:
  - url: http://localhost/api
    description: Local development server
paths:
  /example:
    get:
      summary: Example endpoint
      description: Returns a simple example response
      responses:
        '200':
          description: Successful response
          content:
            application/json:
              schema:
                type: object
                properties:
                  message:
                    type: string
                    example: "API is working"
EOL
    echo "Default OpenAPI specification created at /swagger-editor/openapi.yaml"
    # Ensure the file is writable
    chmod 666 /swagger-editor/openapi.yaml
else
    echo "Using existing OpenAPI specification at /swagger-editor/openapi.yaml"
    # Make sure existing file is writable
    chmod 666 /swagger-editor/openapi.yaml
fi

echo "Swagger Editor initialization complete"