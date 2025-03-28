require_relative 'database'

class Renderer
  attr_reader :title, :site_settings

  def initialize(text, title, site_settings)
    @db = create_database_connection
    @rendered_text = text
    @title = title
    @site_settings = site_settings
  end

  def render_hashtags
    @rendered_text = @rendered_text.gsub(/#(\w+)/) do |match|
      "[#{match}](/tags/#{Regexp.last_match(1)})"
    end
    self
  end

  def render_recent_posts
    @rendered_text = @rendered_text.gsub(/\{\{\s+recent_posts(?:\s+limit:\s+(\d+))?\s+\}\}/) do |match|
      limit = Regexp.last_match(1) || 6
      posts = @db.execute("SELECT title, slug FROM posts WHERE state = 'published' ORDER BY published_at DESC LIMIT ?", limit)
      posts.map { |post| "- [#{post['title']}](/#{post['slug']})" }.join("\n")
    end
    self
  end

  def render_popular_posts
    @rendered_text = @rendered_text.gsub(/\{\{\s+popular_posts(?:\s+limit:\s+(\d+))?(?:,\s+order:\s+"([^"]+)")?\s+\}\}/) do |match|
      limit = Regexp.last_match(1) || 6
      order = Regexp.last_match(2) || 'count'
      posts = @db.execute(<<-SQL, limit: limit, order: order)
        SELECT * FROM (
          SELECT posts.title, posts.slug, COUNT(*) AS count
          FROM visits
          INNER JOIN posts ON visits.entry_id = posts.id AND visits.entry_type = 'post'
          GROUP BY posts.id
          ORDER BY count DESC
          LIMIT :limit
        ) popular_posts ORDER BY :order
      SQL
      posts.map { |post| "- [#{post['title']}](/#{post['slug']})" }.join("\n")
    end
    self
  end

  def render_reply_to_email
    reply_to_email = site_settings["site.interaction.reply_to_email"].to_s.strip
    logger = Logger.new(STDOUT)
    logger.warn(reply_to_email != "")
    logger.warn(title.to_s != "")
    if reply_to_email != "" && title.to_s != ""
      logger.warn("HERE")
      reply_to_email = reply_to_email.gsub(/\{\{\s+subject\s+\}\}/, "subject=Re: #{title}")
      @rendered_text = @rendered_text.strip + "\n\n#{reply_to_email}"
    end

    self
  end

  def finished
    @db.close
    @rendered_text
  end
end
