# Stage 1: Build the application
FROM dart:stable AS build

WORKDIR /app

# Copy pubspec files and get dependencies first to leverage Docker cache
COPY pubspec.* ./
RUN dart pub get

# Copy the rest of the application source code
COPY . .

# Build the Dart Frog server
RUN dart pub global activate dart_frog_cli
RUN dart_frog build

# Compile the standalone worker executables
RUN dart compile exe bin/local_media_finalization_worker.dart -o build/local_media_finalization_worker
RUN dart compile exe bin/media_cleanup_worker.dart -o build/media_cleanup_worker
RUN dart compile exe bin/analytics_sync_worker.dart -o build/analytics_sync_worker

# Stage 2: Create the runtime image
FROM google/dart-runtime

WORKDIR /app

# Copy the built server and worker executables from the build stage
COPY --from=build /app/build .

# Copy the entrypoint script
COPY entrypoint.sh .

# Ensure the entrypoint script is executable
RUN chmod +x entrypoint.sh

# Define a volume for persistent local storage.
# This path must match the LOCAL_STORAGE_PATH in your .env file.
VOLUME /app/storage

# Set the entrypoint script. The CMD will be passed as an argument to this script.
ENTRYPOINT ["/app/entrypoint.sh"]

# Default command to run the server if no other command is specified.
CMD ["server"]