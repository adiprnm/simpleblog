require_relative 'database'

class Renderer
  def initialize(text)
    @db = create_database_connection
    @rendered_text = text
  end

  def render_hashtags
    @rendered_text = @rendered_text.gsub(/#(\w+)/) do |match|
      "[#{match}](/tags/#{Regexp.last_match(1)})"
    end
    self
  end

  def render_recent_posts
    @rendered_text = @rendered_text.gsub(/\{\{\s+recent_posts\s+limit:\s+(\d+),\s+order:\s+"([^"]+)"\s+\}\}/) do |match|
      limit = Regexp.last_match(1) || 6
      order = Regexp.last_match(2) || 'published_at'
      posts = @db.execute("SELECT title, slug FROM posts WHERE state = 'published' ORDER BY ? LIMIT ?", [order, limit])
      posts.map { |post| "- [#{post['title']}](/#{post['slug']})" }.join("\n")
    end
    self
  end

  def render_popular_posts
    @rendered_text = @rendered_text.gsub(/\{\{\s+popular_posts\s+limit:\s+(\d+),\s+order:\s+"([^"]+)"\s+\}\}/) do |match|
      limit = Regexp.last_match(1) || 6
      order = Regexp.last_match(2) || 'count'
      posts = @db.execute(<<-SQL, limit: limit)
        SELECT posts.title, posts.slug, COUNT(*) AS count
        FROM visits
        INNER JOIN posts ON visits.entry_id = posts.id AND visits.entry_type = 'post'
        GROUP BY posts.id
        ORDER BY count DESC
        LIMIT :limit
      SQL
      posts.map { |post| "- [#{post['title']}](/#{post['slug']})" }.join("\n")
    end
    self
  end

  def finished
    @db.close
    @rendered_text
  end
end 