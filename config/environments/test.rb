Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = false
  config.consider_all_requests_local = true
  config.action_controller.allow_forgery_protection = true
  config.hosts = ["www.example.com", "localhost", "127.0.0.1"]
  config.public_file_server.enabled = true
  config.log_level = :warn
end
