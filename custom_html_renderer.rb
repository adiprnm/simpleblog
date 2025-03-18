require 'redcarpet'
require 'rouge'

class CustomHTMLRenderer < Redcarpet::Render::HTML
  def block_code(code, language)
    if language
      formatter = Rouge::Formatters::HTML.new
      lexer = Rouge::Lexer.find_fancy(language, code) || Rouge::Lexers::PlainText.new
      highlighted = formatter.format(lexer.lex(code))

      %(<pre class="highlight"><code class="language-#{language}">#{highlighted}</code></pre>)
    else
      %(<pre><code>#{CGI.escapeHTML(code)}</code></pre>)
    end
  end
end
