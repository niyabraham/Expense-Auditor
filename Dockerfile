# ==========================================
# STAGE 1: Build the Flutter Web App
# ==========================================
# We use a community Flutter image to build the app
FROM ghcr.io/cirruslabs/flutter:stable AS build

# Set the working directory inside the container
WORKDIR /app

# Copy all your code into the container
COPY . .

# Fetch packages and build the web app for production
RUN flutter pub get
RUN flutter build web --release

# ==========================================
# STAGE 2: Serve the App using NGINX
# ==========================================
# We use a tiny Alpine Linux image running NGINX
FROM nginx:alpine

# Copy the compiled web files from Stage 1 into the NGINX public folder
COPY --from=build /app/build/web /usr/share/nginx/html

# Expose port 80 for web traffic
EXPOSE 80

# Start NGINX
CMD ["nginx", "-g", "daemon off;"]
