# Use a pre-built Flutter environment (much faster than cloning)
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app
COPY . .

# Run pub get and build the web app
RUN flutter pub get
RUN flutter build web --release

# Stage 2: Serve with Nginx for maximum performance
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
