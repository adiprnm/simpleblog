# frozen_string_literal: true

require 'sinatra'
require 'redcarpet'
require_relative 'database'

def authorized?
  @auth ||= Rack::Auth::Basic::Request.new(request.env)
  @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == [ENV['APP_USERNAME'], ENV['APP_PASSWORD']]
end

def authorize!
  return if authorized?

  response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
  halt 401, "Not authorized!\n"
end

def slugify(string)
  return '' unless string

  string.downcase.gsub(/[^a-z0-9\- ]/i, '').gsub(/\ /, '-')
end

set :public_folder, "#{__dir__}/public"
set :upload_folder, "#{__dir__}/storage/uploads"

helpers do
  def render_markdown(text)
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
    markdown.render(text)
  end

  def site_settings
    return @site_settings if defined? @site_settings

    db = create_database_connection
    @site_settings ||= db.execute('SELECT key, value FROM settings')
                         .map { |setting| [setting['key'], setting['value']] }
                         .to_h
    db.close
    @site_settings
  end

  def navlinks
    @navlinks ||= create_database_connection.execute('SELECT name, url FROM navlinks ORDER BY position ASC')
  end

  def full_path
    request.base_url + request.path
  end

  def favicon_path
    "#{request.base_url}/images/favicon.svg"
  end

  def og_image_path
    site_settings['site.og_image'] || "#{request.base_url}/images/default-og-image.png"
  end

  def deployment_id
    File.read('deployment_id').chomp
  end
end

get '/' do
  db = create_database_connection
  @page = db.execute("SELECT title, content FROM pages WHERE slug = 'home' LIMIT 1").first
  @recent_posts = db.execute(<<-SQL)
    SELECT title, slug, published_at FROM posts
    WHERE state = 'published'
    ORDER BY published_at DESC LIMIT 6
  SQL
  db.close
  erb :index, layout: :layout
end

get '/blog' do
  db = create_database_connection
  @page = { 'title' => 'Blog' }
  @posts = db.execute("SELECT * FROM posts WHERE state = 'published' ORDER BY published_at DESC")
  @posts = @posts.group_by { |post| DateTime.parse(post['published_at']).to_date.year }
  db.close
  erb :blog, layout: :layout
end

get '/admin' do
  redirect '/admin/posts'
end

get '/admin/posts' do
  authorize!
  @site = { 'title' => 'Admin' }
  db = create_database_connection
  @posts = db.execute('SELECT * FROM posts ORDER BY id DESC')
  db.close
  erb :admin_post_index, layout: :admin_layout
end

get '/admin/posts/new' do
  authorize!
  @errors = {}
  @post = {}
  @site = { 'title' => 'New Post' }
  erb :admin_post_new, layout: :admin_layout
end

post '/admin/posts' do
  authorize!
  @errors = {}
  @errors['title'] = 'Title is required' if params['title'].empty?
  @errors['content'] = 'Content is required' if params['content'].empty?
  if @errors.any?
    @post = params.slice('title', 'content')
    @site = { 'title' => 'New Post' }
    return erb :admin_post_new, layout: :admin_layout
  end

  slug = slugify(params['title'])
  db = create_database_connection
  state, published_at = if params['commit'] == 'Publish'
                          ['published', Time.now.to_s]
                        elsif params['commit'] == 'Save as Draft'
                          ['draft', nil]
                        end
  db.execute(
    'INSERT INTO posts (title, content, slug, state, published_at) VALUES (?, ?, ?, ?, ?)',
    [params['title'], params['content'], slug, state, published_at]
  )
  db.close
  redirect '/admin/posts'
end

get '/admin/posts/:id/edit' do
  authorize!
  @errors = {}
  db = create_database_connection
  @post = db.execute('SELECT * FROM posts WHERE id = ? LIMIT 1', params['id']).first
  halt 404, 'Post not found' unless @post
  @site = { 'title' => "Edit #{@post['title']}" }
  db.close
  erb :admin_post_edit, layout: :admin_layout
end

put '/admin/posts/:id' do
  authorize!
  db = create_database_connection
  post = db.execute('SELECT * FROM posts WHERE id = ? LIMIT 1', params['id']).first
  halt 404, 'Post not found' unless post
  @errors = {}
  @errors['title'] = 'Title is required' if params['title'].empty?
  @errors['content'] = 'Content is required' if params['content'].empty?
  if @errors.any?
    @post = params.slice('title', 'content').merge('id' => params['id'])
    @site = { 'title' => 'Edit Post' }
    return erb :admin_post_edit, layout: :admin_layout
  end

  state = if ['Change to Draft', 'Save as Draft'].include?(params['commit'])
            'draft'
          else
            'published'
          end
  published_at = post['published_at'] || Time.now.to_s
  slug = params['slug'].to_s.length.positive? ? slugify(params['slug']) : slugify(params['title'])
  to_be_updated_fields = %w[title content state published_at]
  to_be_updated_values = [params['title'], params['content'], state, published_at]
  if slug && slug != post['slug']
    to_be_updated_fields << 'slug'
    to_be_updated_values << slug
  end
  to_be_updated_values << params['id']

  db.execute(
    "UPDATE posts SET #{to_be_updated_fields.map { |f| "#{f} = ?" }.join(', ')}, updated_at = time('now') WHERE id = ?",
    to_be_updated_values
  )
  db.close
  redirect '/admin/posts'
end

delete '/admin/posts/:id' do
  authorize!
  db = create_database_connection
  exist = db.execute('SELECT 1 FROM posts WHERE id = ? LIMIT 1', params['id']).first
  halt 404, 'Post not found' unless exist
  db.execute('DELETE FROM posts WHERE id = ?', params['id'])
  db.close
  redirect '/admin/posts'
end

get '/admin/pages' do
  authorize!
  @site = { 'title' => 'Admin' }
  db = create_database_connection
  @pages = db.execute('SELECT * FROM pages ORDER BY id DESC')
  db.close
  erb :admin_page_index, layout: :admin_layout
end

get '/admin/pages/new' do
  authorize!
  @errors = {}
  @page = {}
  @site = { 'title' => 'New Post' }
  erb :admin_page_new, layout: :admin_layout
end

post '/admin/pages' do
  authorize!
  @errors = {}
  @errors['title'] = 'Title is required' if params['title'].empty?
  @errors['content'] = 'Content is required' if params['content'].empty?
  if @errors.any?
    @page = params.slice('title', 'content')
    @site = { 'title' => 'New Post' }
    return erb :admin_page_new, layout: :admin_layout
  end

  slug = slugify(params['title'])
  db = create_database_connection
  state, published_at = if params['commit'] == 'Publish'
                          ['published', Time.now.to_s]
                        elsif params['commit'] == 'Save as Draft'
                          ['draft', nil]
                        end
  db.execute(
    'INSERT INTO pages (title, content, state, published_at, slug) VALUES (?, ?, ?, ?, ?)',
    [params['title'], params['content'], state, published_at, slug]
  )
  db.close
  redirect '/admin/pages'
end

get '/admin/pages/:id/edit' do
  authorize!
  @errors = {}
  db = create_database_connection
  @page = db.execute('SELECT * FROM pages WHERE id = ? LIMIT 1', params['id']).first
  halt 404, 'Page not found' unless @page
  @site = { 'title' => "Edit #{@page['title']}" }
  db.close
  erb :admin_page_edit, layout: :admin_layout
end

put '/admin/pages/:id' do
  authorize!
  db = create_database_connection
  page = db.execute('SELECT * FROM pages WHERE id = ? LIMIT 1', params['id']).first
  halt 404, 'Page not found' unless page

  @errors = {}
  @errors['title'] = 'Title is required' if params['title'].empty?
  @errors['content'] = 'Content is required' if params['content'].empty?
  if @errors.any?
    @post = params.slice('title', 'content').merge('id' => params['id'])
    @site = { 'title' => 'Edit Post' }
    return erb :admin_page_edit, layout: :admin_layout
  end

  state = if ['Change to Draft', 'Save as Draft'].include?(params['commit'])
            'draft'
          else
            'published'
          end
  published_at = page['published_at'] || Time.now.to_s
  slug = params['slug'].to_s.length.positive? ? slugify(params['slug']) : slugify(params['title'])
  to_be_updated_fields = %w[title content state published_at]
  to_be_updated_values = [params['title'], params['content'], state, published_at]
  if slug && slug != page['slug']
    to_be_updated_fields << 'slug'
    to_be_updated_values << slug
  end
  to_be_updated_values << params['id']

  db.execute(
    "UPDATE pages SET #{to_be_updated_fields.map { |f| "#{f} = ?" }.join(', ')}, updated_at = time('now') WHERE id = ?",
    to_be_updated_values
  )
  db.close
  redirect '/admin/pages'
end

delete '/admin/pages/:id' do
  authorize!
  db = create_database_connection
  exist = db.execute('SELECT 1 FROM pages WHERE id = ? LIMIT 1', params['id']).first
  halt 404, 'Page not found' unless exist
  db.execute('DELETE FROM pages WHERE id = ?', params['id'])
  db.close
  redirect '/admin/pages'
end

get '/admin/navlinks' do
  authorize!
  db = create_database_connection
  @navlinks = db.execute('SELECT * FROM navlinks ORDER BY position ASC')
  db.close
  @site = { 'title' => 'Navlinks' }
  erb :admin_navlink_index, layout: :admin_layout
end

get '/admin/navlinks/new' do
  authorize!
  db = create_database_connection
  last_link =  db.execute('SELECT position FROM navlinks ORDER BY position DESC LIMIT 1').first
  @navlink = { 'position' => last_link['position'].to_i + 1 }
  @site = { 'title' => 'New Navlink' }
  erb :admin_navlink_new, layout: :admin_layout
end

post '/admin/navlinks' do
  authorize!
  db = create_database_connection
  last_link = db.execute('SELECT position FROM navlinks ORDER BY position DESC LIMIT 1').first
  params['position'] = params['position'].to_i.clamp(1, last_link['position'].to_i + 1)

  db.execute(
    'UPDATE navlinks SET position = position + 1 WHERE position >= ?',
    params['position']
  )
  db.execute(
    'INSERT INTO navlinks (name, position, url) VALUES (?, ?, ?)',
    [params['name'], params['position'], params['url']]
  )
  db.close
  redirect '/admin/navlinks'
end

get '/admin/navlinks/:id/edit' do
  authorize!
  db = create_database_connection
  @navlink = db.execute('SELECT * FROM navlinks WHERE id = ? LIMIT 1', params['id']).first
  halt 404, 'Navlink not found' unless @navlink
  db.close
  @site = { 'title' => "Edit #{@navlink['name']}" }
  erb :admin_navlink_edit, layout: :admin_layout
end

put '/admin/navlinks/:id' do
  authorize!
  db = create_database_connection
  navlink = db.execute('SELECT * FROM navlinks WHERE id = ? LIMIT 1', params['id']).first
  halt 404, 'Navlink not found' unless navlink

  last_link = db.execute('SELECT position FROM navlinks ORDER BY position DESC LIMIT 1').first
  params['position'] = params['position'].to_i.clamp(1, last_link['position'].to_i + 1)

  if params['position'].to_i > navlink['position'].to_i
    db.execute(
      'UPDATE navlinks SET position = position - 1 WHERE position > ?',
      navlink['position']
    )
    db.execute(
      'UPDATE navlinks SET position = position + 1 WHERE position >= ?',
      params['position']
    )
  elsif params['position'].to_i < navlink['position'].to_i
    db.execute(
      'UPDATE navlinks SET position = position + 1 WHERE position < ?',
      navlink['position']
    )
    db.execute(
      'UPDATE navlinks SET position = position - 1 WHERE position <= ?',
      params['position']
    )
  end

  db.execute(
    'UPDATE navlinks SET name = ?, position = ?, url = ? WHERE id = ?',
    [params['name'], params['position'], params['url'], params['id']]
  )
  db.close
  redirect '/admin/navlinks'
end

delete '/admin/navlinks/:id' do
  authorize!
  db = create_database_connection
  navlink = db.execute('SELECT position FROM navlinks WHERE id = ? LIMIT 1', params['id']).first
  halt 404, 'Navlink not found' unless navlink
  db.execute('UPDATE navlinks SET position = position - 1 WHERE position > ?', navlink['position'])
  db.execute('DELETE FROM navlinks WHERE id = ?', params['id'])
  db.close
  redirect '/admin/navlinks'
end

get '/admin/settings' do
  authorize!
  @site = { 'title' => 'Settings' }
  @errors = {}
  @settings = site_settings
  erb :admin_settings, layout: :admin_layout
end

put '/admin/settings' do
  authorize!
  settings = params['site_settings']
  @errors = {}
  settings.each do |setting|
    key, value = setting.values_at('key', 'value')
    @errors[key] = "#{key} is required" if value.empty?
  end
  if @errors.any?
    @site = { 'title' => 'Settings' }
    @settings = {}.tap do |hash|
      settings.each do |setting|
        key, value = setting.values_at('key', 'value')
        hash[key] = value
      end
    end
    return erb :admin_settings, layout: :admin_layout
  end

  db = create_database_connection
  settings.each do |setting|
    key, value = setting.values_at('key', 'value')
    db.execute('UPDATE settings SET value = ? WHERE key = ?', [value, key])
  end
  db.close

  redirect '/admin/settings'
end

post '/admin/upload' do
  content_type :json

  upload = params['file']
  if upload
    filename = "#{SecureRandom.uuid}.#{upload[:filename].split('.').last}"
    filepath = File.join(settings.upload_folder, filename)
    server_path = File.join(request.base_url, 'uploads', filename)
    File.open(filepath, 'wb') do |f|
      f.write(upload['tempfile'].read)
    end
    { success: true, path: server_path, filename: upload[:filename] }.to_json
  else
    status 400
    { success: false, message: 'No file uploaded' }.to_json
  end
end

get '/uploads/:filename' do |filename|
  file_path = File.expand_path(File.join(settings.public_folder, 'uploads', filename))

  if File.exist?(file_path)
    send_file file_path
  else
    halt 404, 'File not found'
  end
end

get '/:slug' do
  db = create_database_connection
  @post = db.execute('SELECT title, published_at, content FROM posts WHERE slug = ? LIMIT 1', params['slug']).first
  @show_date = !@post.nil?
  @post ||= db.execute('SELECT title, published_at, content FROM pages WHERE slug = ? LIMIT 1', params['slug']).first
  halt 404, 'Post/page not found!' unless @post
  @page = @post
  db.close
  erb :post, layout: :layout
end
