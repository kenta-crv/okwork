# Puma can serve each request in a thread from an internal thread pool.
# The `threads` method setting takes two numbers: a minimum and maximum.

threads_count = ENV.fetch("RAILS_MAX_THREADS") { 3 }
threads threads_count, threads_count

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
port        ENV.fetch("PORT") { 3000 }

# Specifies the `environment` that Puma will run in.
environment ENV.fetch("RAILS_ENV") { "production" }

# Specifies the `pidfile` that Puma will use.
pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }

# Workers (cluster mode)
# 6GB環境では基本1固定が安全ライン
workers ENV.fetch("WEB_CONCURRENCY") { 1 }

# Important: enable Copy on Write optimization
# This reduces memory usage when using workers
preload_app!

# Allow puma to be restarted by `rails restart` command.
plugin :tmp_restart