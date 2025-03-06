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
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["docker-entrypoint.sh"]

# Expose the port Puma runs on
EXPOSE 3000

# Command to run the app
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]

