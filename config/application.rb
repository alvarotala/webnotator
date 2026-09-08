require_relative "boot"
require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "rails/test_unit/railtie"
Bundler.require(*Rails.groups)
module Webnotator
  class Application < Rails::Application
    config.load_defaults 8.1
    config.time_zone = "UTC"
    config.cache_store = :memory_store, { size: 16 * 1024 * 1024 }
    config.autoload_lib(ignore: %w[assets tasks])
    config.secret_key_base = ENV.fetch("SECRET_KEY_BASE") { Rails.env.test? ? "test-" * 32 : raise("SECRET_KEY_BASE is required") }
    config.hosts = ENV.fetch("ALLOWED_HOSTS", "localhost,127.0.0.1,webnotator.sadmonkey.app").split(",")
    config.session_store :cookie_store, key: "_webnotator", same_site: :lax, httponly: true, secure: ENV["HTTPS"] == "true", expire_after: 43_200
    config.action_dispatch.default_headers["Referrer-Policy"] = "no-referrer"
    config.action_dispatch.default_headers["X-Content-Type-Options"] = "nosniff"
    config.filter_parameters += [:password, :token, :authorization, :invite_token]
  end
end
