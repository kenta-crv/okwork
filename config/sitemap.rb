SitemapGenerator::Sitemap.default_host = "https://okey.work"

SitemapGenerator::Sitemap.create do
  # トップページ
  add root_path, changefreq: 'hourly', priority: 1.0

  # 各ジャンルLP
  pages = %w[
    daily
  ]

  pages.each do |page|
    add "/#{page}", changefreq: 'monthly', priority: 0.7
  end

  # Column（LP配下）
  Column.find_each do |column|
    next unless column.code.present?   # code があるものだけ追加
    lp = column.genre # 例: "cleaning"

    add "/columns/#{column.code}",
        lastmod: column.updated_at,
        priority: 0.5
  end
end