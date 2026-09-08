ENV["RAILS_ENV"] = "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  parallelize(workers: 1)
  setup { Rails.cache.clear }
end

class ActionDispatch::IntegrationTest
  def sign_in
    @admin = Admin.create!(email: "admin@example.com", password: "test-password-long")
    get "/api/session"
    @csrf = response.parsed_body.fetch("csrf_token")
    post "/api/session", params: {email: @admin.email, password: "test-password-long"}, as: :json, headers: {"X-CSRF-Token" => @csrf}
    assert_response :success
    @csrf = response.parsed_body.fetch("csrf_token")
  end

  def csrf_headers
    { "X-CSRF-Token" => @csrf }
  end

  def make_project(name = "Beta", origin = "https://beta.example.com")
    Project.create!(name: name, origins: [origin])
  end

  def widget_headers(project)
    {"Origin" => project.origins.first, "Authorization" => "Bearer #{project.invite_token}"}
  end

  def feedback_params(project, overrides = {})
    {author_name: "María", body: "Este select debe permitir buscar", kind: "change", page_url: "#{project.origins.first}/reservar", page_title: "Reserva", client_id: SecureRandom.uuid, element: {selector: "#service", tag: "select", text: "Servicio"}.to_json, viewport: {width: 1280, height: 800}.to_json}.merge(overrides)
  end
end
