namespace :data do
  task migrate: :environment do
    Rails.application.eager_load!
    puts "Loading SQLite config..."
    sqlite_config = Rails.configuration.database_configuration["sqlite"]
    pg_config     = Rails.configuration.database_configuration["development"]

    # SQLite接続
    ActiveRecord::Base.establish_connection(sqlite_config)

    models = ActiveRecord::Base.descendants.select do |m|
      m.table_exists? && !m.abstract_class?
    end

    dump = {}

    models.each do |model|
      puts "Dumping #{model.name}..."
      dump[model] = model.unscoped.pluck(Arel.star).map do |row|
        model.column_names.zip(row).to_h
      end
    end

    # PostgreSQLへ接続切り替え
    ActiveRecord::Base.establish_connection(pg_config)

    dump.each do |model, rows|
      next if rows.empty?

      puts "Importing #{model.name} (#{rows.size} rows)..."
      model.insert_all!(rows)
    end

    puts "=== Migration completed successfully ==="
  end
end
