# Use official Nginx image
FROM nginx:latest

# Copy frontend files to the Nginx web server directory
COPY index.html /usr/share/nginx/html/

# Expose port 80 for serving the webpage
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
