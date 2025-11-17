# Use the official Node.js image with the Alpine Linux base image for minimal size
FROM node:alpine

# Set the environment to production to avoid installing unnecessary development dependencies
ENV NODE_ENV=production

# Create a non-root user and group (appuser) for running the application
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Set the working directory inside the container
WORKDIR /app

# Copy only the package.json and package-lock.json (this helps with caching layers and avoiding re-installing dependencies unnecessarily)
COPY package*.json ./

# Install only production dependencies (omit dev dependencies)
RUN npm install --only=production

# Copy the rest of the application files to the container
COPY . .

# Change ownership of the files to the non-root user
RUN chown -R appuser:appgroup /app

# Switch to the non-root user to run the application
USER appuser

# Expose the port that the application will run on (adjust if necessary)
EXPOSE 3000

# Start the application
CMD ["npm", "start"]