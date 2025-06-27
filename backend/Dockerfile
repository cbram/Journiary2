# Use a lightweight Node.js image
FROM node:18-slim

# Set the working directory
WORKDIR /usr/src/app

# Copy package.json and package-lock.json
COPY package*.json ./

# Install dependencies
RUN npm install --legacy-peer-deps

# Copy the rest of the application's source code
COPY . .

# Expose the port the app runs on
EXPOSE 4000

# Run the server using ts-node
CMD ["npm", "run", "dev"] 