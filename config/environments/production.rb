Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.public_file_server.enabled = true
  config.log_level = :info
  config.logger = ActiveSupport::Logger.new($stdout)
  config.assume_ssl = ENV["HTTPS"] == "true"
  config.force_ssl = ENV["HTTPS"] == "true"
  config.silence_healthcheck_path = "/up"
end
