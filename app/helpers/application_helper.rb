module ApplicationHelper
  def default_meta_tags
    {
      site: "豊富な人材集客力で企業の人材不足を解消|『J Work』",
      description: "豊富な人材集客力で企業の人材不足を解消|『J Work』。軽貨物・警備・建設・清掃業等様々な業界で活躍しています。",
      canonical: request.original_url,
      charset: "UTF-8",
      reverse: true,
      separator: '|',
      icon: [
        { href: image_url('favicon.ico') },
        { href: image_url('favicon.ico'),  rel: 'apple-touch-icon' },
      ],
    }
  end

  def breadcrumb_list_json_ld
    return if !defined?(breadcrumbs) || breadcrumbs.blank?

    items = breadcrumbs.each_with_index.map do |crumb, i|
      name = crumb[:label] || crumb[:name]
      path = crumb[:path]

      item = {
        "@type" => "ListItem",
        "position" => i + 1,
        "name" => name
      }
      item["item"] = path.present? ? "#{request.base_url}#{path}" : request.original_url
      item
    end

    {
      "@context" => "https://schema.org",
      "@type" => "BreadcrumbList",
      "itemListElement" => items
    }.to_json
  end

  def organization_json_ld
    {
      "@context" => "https://schema.org",
      "@type" => "Organization",
      "name" => "OK Work",
      "legalName" => "株式会社セールスプロ",
      "url" => "https://okey.work/",
      "logo" => "https://okey.work#{image_path('favicon.ico')}",
      "description" => "清掃・軽貨物・人材など、現場の課題を人材力で解決する OK Work。",
      "address" => {
        "@type" => "PostalAddress",
        "streetAddress" => "芝5-27-3 MBC・Aー9",
        "addressLocality" => "港区",
        "addressRegion" => "東京都",
        "addressCountry" => "JP"
      }
    }.to_json
  end

  def website_json_ld
    {
      "@context" => "https://schema.org",
      "@type" => "WebSite",
      "name" => "OK Work",
      "url" => "https://okey.work/",
      "inLanguage" => "ja",
      "publisher" => {
        "@type" => "Organization",
        "name" => "株式会社セールスプロ"
      }
    }.to_json
  end

  def faq_page_json_ld(items)
    entities = Array(items).filter_map do |item|
      q = (item.is_a?(Array) ? item[0] : (item[:q] || item["q"])).to_s.strip
      a = (item.is_a?(Array) ? item[1] : (item[:a] || item["a"])).to_s.strip
      next if q.blank? || a.blank?

      {
        "@type" => "Question",
        "name" => q,
        "acceptedAnswer" => {
          "@type" => "Answer",
          "text" => a
        }
      }
    end
    return if entities.blank?

    {
      "@context" => "https://schema.org",
      "@type" => "FAQPage",
      "mainEntity" => entities
    }.to_json
  end
end
