FROM nginx:alpine

# Install necessary tools
RUN apk add --no-cache bash jq

# Copy configuration and script
COPY nginx-browser.conf /etc/nginx/conf.d/default.conf
COPY generate-file-list.sh /usr/local/bin/generate-file-list.sh
COPY index.html /usr/share/nginx/html/index.html

# Make the script executable
RUN chmod +x /usr/local/bin/generate-file-list.sh

# Set up a healthcheck
HEALTHCHECK --interval=30s --timeout=3s CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

# Run the script to generate the file list periodically
CMD ["/bin/sh", "-c", "/usr/local/bin/generate-file-list.sh & nginx -g 'daemon off;'"]