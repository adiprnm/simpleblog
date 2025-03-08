# frozen_string_literal: true

threads 1, 1

port ENV.fetch('APP_PORT', 3000)
environment ENV.fetch('RACK_ENV', 'development')

# Preload app for better performance
preload_app!

drain_on_shutdown
