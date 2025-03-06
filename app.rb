# frozen_string_literal: true

require 'sinatra'
require 'redcarpet'
require_relative 'database'

def authorized?
  @auth ||= Rack::Auth::Basic::Request.new(request.env)
  @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == ['admin', 'password']
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
end

get '/' do
  db = create_database_connection
  @page = db.execute("SELECT title, content FROM pages WHERE slug = 'home' LIMIT 1").first
  @navlinks = db.execute('SELECT name, url FROM navlinks ORDER BY position ASC')
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
  if ['Change to Draft', 'Save as Draft'].include?(params['commit'])
    db.execute("UPDATE posts SET state = 'draft', updated_at = time('now') WHERE id = ?", params['id'])
    db.close
    return redirect '/admin/posts'
  end

  @errors = {}
  @errors['title'] = 'Title is required' if params['title'].empty?
  @errors['content'] = 'Content is required' if params['content'].empty?
  if @errors.any?
    @post = params.slice('title', 'content').merge('id' => params['id'])
    @site = { 'title' => 'Edit Post' }
    return erb :admin_post_edit, layout: :admin_layout
  end

  slug = params['slug'].to_s.length.positive? ? slugify(params['slug']) : slugify(params['title'])
  to_be_updated_fields = %w[title content]
  to_be_updated_values = [params['title'], params['content']]
  if slug && slug != post['slug']
    to_be_updated_fields << 'slug'
    to_be_updated_values << slug
  end
  to_be_updated_values << params['id']

  db.execute(
    "UPDATE posts SET #{to_be_updated_fields.map { |f| "#{f} = ?" }.join(', ')}, state = 'published', updated_at = time('now') WHERE id = ?",
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
  if ['Change to Draft', 'Save as Draft'].include?(params['commit'])
    db.execute("UPDATE pages SET state = 'draft', updated_at = time('now') WHERE id = ?", params['id'])
    db.close
    return redirect '/admin/pages'
  end

  @errors = {}
  @errors['title'] = 'Title is required' if params['title'].empty?
  @errors['content'] = 'Content is required' if params['content'].empty?
  if @errors.any?
    @post = params.slice('title', 'content').merge('id' => params['id'])
    @site = { 'title' => 'Edit Post' }
    return erb :admin_page_edit, layout: :admin_layout
  end

  slug = params['slug'].to_s.length.positive? ? slugify(params['slug']) : slugify(params['title'])
  to_be_updated_fields = %w[title content]
  to_be_updated_values = [params['title'], params['content']]
  if slug && slug != page['slug']
    to_be_updated_fields << 'slug'
    to_be_updated_values << slug
  end
  to_be_updated_values << params['id']

  db.execute(
    "UPDATE pages SET #{to_be_updated_fields.map { |f| "#{f} = ?" }.join(', ')}, state = 'published', updated_at = time('now') WHERE id = ?",
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

get '/:slug' do
  db = create_database_connection
  @post = db.execute('SELECT title, published_at, content FROM posts WHERE slug = ? LIMIT 1', params['slug']).first
  halt 404, 'Post not found' unless @post
  @page = @post
  db.close
  erb :post, layout: :layout
end
