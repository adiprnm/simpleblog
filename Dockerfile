FROM ruby:3.3 AS builder

WORKDIR /app

# Install dependencies
COPY Gemfile Gemfile.lock ./
RUN bundle install --without development test

# Copy the application code
COPY . .

# Use a smaller base image for the final stage
FROM ruby:3.3-slim AS runtime

WORKDIR /app

# Copy the installed gems from the builder stage
COPY --from=builder /usr/local/bundle /usr/local/bundle

# Copy the application code
COPY . .

# Install ImageMagick
RUN apt-get update && apt-get install -y imagemagick

# Set the deployment ID for asset caching
RUN date +%s > deployment_id

# Copy the entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/

# Make the entrypoint script executable
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]

# Expose the port Puma runs on
EXPOSE 3000

# Command to run the app
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]

