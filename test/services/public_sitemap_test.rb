require "test_helper"
require "tmpdir"
require Rails.root.join("lib/public_sitemap")

class PublicSitemapTest < ActiveSupport::TestCase
  INDEX_HTML = <<~HTML.freeze
    <html><body>
      <a href="/columns/alpha">古い記事</a>
      <a href="/columns/beta">新しい記事</a>
      <a href="/columns/gone">存在しない記事</a>
      <a href="/columns/moved">転送される記事</a>
      <a href="/columns/hidden">noindexの記事</a>
    </body></html>
  HTML

  setup do
    @original_public_path = SitemapGenerator::Sitemap.public_path
    @original_verbose = SitemapGenerator::Sitemap.verbose
    SitemapGenerator::Sitemap.verbose = false
  end

  teardown do
    SitemapGenerator::Sitemap.public_path = @original_public_path
    SitemapGenerator::Sitemap.verbose = @original_verbose
  end

  test "okey.work sitemap gives each article its own lastmod and drops non-public urls" do
    host = "https://okey.work"
    entries = PublicSitemap.compose(
      host: host,
      static_entries: [
        { path: "/", changefreq: "hourly", priority: 1.0 },
        { path: "/daily", changefreq: "monthly", priority: 0.7 },
        { path: "/retired", changefreq: "monthly", priority: 0.7 },
        { path: "/secret", changefreq: "monthly", priority: 0.7 }
      ],
      fetcher: method(:fake_response)
    )

    Dir.mktmpdir("okey-sitemap") do |dir|
      PublicSitemap.write!(host: host, entries: entries, public_path: dir)
      urls = sitemap_url_lastmods(File.read(File.join(dir, "sitemap.xml")))

      alpha = urls.fetch("#{host}/columns/alpha")
      beta = urls.fetch("#{host}/columns/beta")
      assert_includes alpha, "2024-01-15"
      assert_includes beta, "2025-06-02"
      refute_equal alpha, beta

      assert_includes urls.fetch("#{host}/columns"), "2025-06-02"
      assert urls.key?(host)
      assert_nil urls[host]
      assert_nil urls["#{host}/daily"]

      refute urls.key?("#{host}/columns/gone")
      refute urls.key?("#{host}/columns/moved")
      refute urls.key?("#{host}/columns/hidden")
      refute urls.key?("#{host}/retired")
      refute urls.key?("#{host}/secret")

      today = Date.current.iso8601
      urls.each do |loc, lastmod|
        refute lastmod&.start_with?(today), "#{loc} の lastmod が生成日になっています"
      end
    end
  end

  private

  def fake_response(path)
    case path
    when "/", "/daily"
      page(200, "<html></html>")
    when "/retired"
      page(301, "")
    when "/secret"
      page(200, '<html><head><meta name="robots" content="noindex"></head></html>')
    when "/columns", "/columns?page=1"
      page(200, INDEX_HTML)
    when "/columns?page=2"
      page(200, "<html></html>")
    when "/columns/alpha"
      page(200, article_html("2024-01-15T10:00:00+09:00"))
    when "/columns/beta"
      page(200, article_html("2025-06-02T08:30:00+09:00"))
    when "/columns/gone"
      page(404, "missing")
    when "/columns/moved"
      page(301, "")
    when "/columns/hidden"
      page(200, '<html><head><meta name="robots" content="noindex, follow"></head></html>')
    else
      raise "想定外の取得です: #{path}"
    end
  end

  def page(code, body)
    PublicSitemap::Response.new(code: code, body: body)
  end

  def article_html(modified_at)
    %(<html><head><meta property="article:modified_time" content="#{modified_at}"></head></html>)
  end

  def sitemap_url_lastmods(xml)
    document = Nokogiri::XML(xml)
    document.remove_namespaces!
    document.css("url").each_with_object({}) do |node, result|
      result[node.at_css("loc").text] = node.at_css("lastmod")&.text
    end
  end
end
