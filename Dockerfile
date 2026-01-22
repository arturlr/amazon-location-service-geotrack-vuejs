# Use Node.js LTS version
FROM node:20-slim

# Set working directory
WORKDIR /app

# Copy package files first (for layer caching)
COPY webapp/package*.json ./

# Install dependencies
RUN npm install

# Copy application code
COPY webapp/ .

# Build the application
RUN npm run build

# Expose Vite preview port
EXPOSE 4173

# Start the preview server
CMD ["npm", "run", "preview", "--", "--host", "0.0.0.0", "--port", "4173"]
