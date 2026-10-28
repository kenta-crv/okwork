require Rails.root.join("lib/public_sitemap")

host = "https://okey.work"
entries = PublicSitemap.compose(
  host: host,
  static_entries: [
    { path: "/", changefreq: "hourly", priority: 1.0 },
    { path: "/daily", changefreq: "monthly", priority: 0.7 },
    { path: "/daily-cleaning", changefreq: "monthly", priority: 0.7 },
    { path: "/staffing", changefreq: "monthly", priority: 0.7 }
  ]
)

PublicSitemap.write!(host: host, entries: entries)
