require 'csv'

file_path = Rails.root.join('security.csv')

CSV.foreach(file_path, headers: true) do |row|
  Column.create!(
    parent_id: row['parent_id'].present? ? row['parent_id'].to_i : nil,
    title: row['title'],
    genre: row['genre'],
    article_type: row['article_type']
  )
end

#サイトのブランチ表示（ローカル）
sudo vi /etc/hosts