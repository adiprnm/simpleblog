class CloudflareRealIP
  def initialize(app)
    @app = app
  end

  def call(env)
    env['REMOTE_ADDR'] = if env['HTTP_CF_CONNECTING_IP']
        env['HTTP_CF_CONNECTING_IP']
      elsif env['HTTP_X_FORWARDED_FOR']
        env['HTTP_X_FORWARDED_FOR'].split(',').first.strip
      else
        env['REMOTE_ADDR']
      end

    @app.call(env)
  end
end