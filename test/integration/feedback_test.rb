require "test_helper"

class FeedbackTest < ActionDispatch::IntegrationTest
  test "admin endpoints require login and login requires CSRF" do
    get "/api/projects"
    assert_response :unauthorized
    post "/api/session", params: {email: "a", password: "b"}, as: :json
    assert_response :unprocessable_entity
    sign_in
    get "/api/projects"
    assert_response :success
    delete "/api/session", headers: csrf_headers
    assert_response :success
    get "/api/projects"
    assert_response :unauthorized
  end

  test "admin can create configure and rotate project invitation" do
    sign_in
    post "/api/projects", params: {project: {name: "Agendario", origins: ["https://agendario.app"]}}, as: :json, headers: csrf_headers
    assert_response :created
    project = Project.last
    token = project.invite_token
    patch "/api/projects/#{project.id}", params: {project: {origins: ["https://beta.agendario.app"]}}, as: :json, headers: csrf_headers
    assert_response :success
    assert_equal ["https://beta.agendario.app"], project.reload.origins
    post "/api/projects/#{project.id}/rotate_invitation", headers: csrf_headers
    assert_response :success
    assert_not_equal token, project.reload.invite_token
    get "/api/invitations/#{token}"
    assert_response :not_found
    get "/api/invitations/#{project.invite_token}"
    assert_response :success
    assert_nil response.parsed_body["invite_token"]
  end

  test "origins must be exact and include a scheme without paths" do
    sign_in
    [[], ["agendario.app"], ["https://agendario.app/path"], ["https://agendario.app/"], ["javascript:alert(1)"], ["https://user:pass@agendario.app"]].each do |origins|
      post "/api/projects", params: {project: {name: "Test", origins: origins}}, as: :json, headers: csrf_headers
      assert_response :unprocessable_entity
    end
  end

  test "preflight only permits configured origin and no credentials are shared" do
    project = make_project
    options "/api/widget/#{project.public_key}/annotations", headers: {"Origin" => project.origins.first}
    assert_response :no_content
    assert_equal project.origins.first, response.headers["Access-Control-Allow-Origin"]
    assert_nil response.headers["Access-Control-Allow-Credentials"]
    options "/api/widget/#{project.public_key}/annotations", headers: {"Origin" => "https://evil.example.com"}
    assert_response :forbidden
    assert_nil response.headers["Access-Control-Allow-Origin"]
  end

  test "public key alone cannot submit and revoked invitation stops working" do
    project = make_project
    post "/api/widget/#{project.public_key}/annotations", params: feedback_params(project), headers: {"Origin" => project.origins.first}
    assert_response :unauthorized
    old_headers = widget_headers(project)
    project.update!(invite_token: SecureRandom.urlsafe_base64(32))
    post "/api/widget/#{project.public_key}/annotations", params: feedback_params(project), headers: old_headers
    assert_response :unauthorized
    assert_equal 0, project.annotations.count
  end

  test "same-origin context works without an Origin header but still needs invitation" do
    project = make_project("Own site", "http://www.example.com")
    get "/api/widget/#{project.public_key}/context", headers: {"Authorization" => "Bearer #{project.invite_token}"}
    assert_response :success
    assert_equal "Own site", response.parsed_body["name"]
    get "/api/widget/#{project.public_key}/context"
    assert_response :unauthorized
  end

  test "feedback is stored with element context and retries do not duplicate" do
    project = make_project
    payload = feedback_params(project)
    2.times do
      post "/api/widget/#{project.public_key}/annotations", params: payload, headers: widget_headers(project)
      assert_response :success
    end
    assert_equal 1, project.annotations.count
    note = project.annotations.first
    assert_equal "#service", note.element["selector"]
    assert_equal "pending", note.status
    assert_equal "María", note.author_name
  end

  test "malformed context invalid kinds and wrong page are rejected" do
    project = make_project
    [{element: "[]"}, {element: "not json"}, {element: {text: {nested: true}}.to_json}, {viewport: {width: -3}.to_json}, {kind: "unknown"}, {body: ""}, {page_url: "https://evil.example.com"}, {page_url: "#{project.origins.first}/?token=secret"}].each do |invalid|
      post "/api/widget/#{project.public_key}/annotations", params: feedback_params(project, invalid), headers: widget_headers(project)
      assert_response :unprocessable_entity
    end
    assert_equal 0, project.annotations.count
  end

  test "project boundary applies to note reads and admin updates" do
    project = make_project
    other = make_project("Other", "https://other.example.com")
    post "/api/widget/#{project.public_key}/annotations", params: feedback_params(project), headers: widget_headers(project)
    note = project.annotations.first
    get "/api/widget/#{other.public_key}/annotations/#{note.id}", headers: widget_headers(other)
    assert_response :not_found
    sign_in
    patch "/api/projects/#{other.id}/annotations/#{note.id}", params: {annotation: {status: "resolved"}}, as: :json, headers: csrf_headers
    assert_response :not_found
    patch "/api/projects/#{project.id}/annotations/#{note.id}", params: {annotation: {status: "resolved", body: "replace"}}, as: :json, headers: csrf_headers
    assert_response :success
    assert_equal "resolved", note.reload.status
    assert_not_equal "replace", note.body
  end

  test "filters and pagination apply to one project" do
    project = make_project
    32.times do |index|
      project.annotations.create!(author_name: "Ana", body: "Revisar #{index}", kind: index.even? ? "bug" : "change", status: index.even? ? "resolved" : "pending", page_url: "#{project.origins.first}/#{index.even? ? 'a' : 'b'}", client_id: SecureRandom.uuid)
    end
    sign_in
    get "/api/projects/#{project.id}/annotations"
    assert_equal 30, response.parsed_body["items"].length
    assert_equal 32, response.parsed_body["total"]
    get "/api/projects/#{project.id}/annotations", params: {number: 2}
    assert_equal 2, response.parsed_body["items"].length
    get "/api/projects/#{project.id}/annotations", params: {status: "pending", kind: "change", page: "#{project.origins.first}/b", q: "Revisar 1"}
    assert_equal 6, response.parsed_body["total"]
  end

  test "image attachment remains private and invalid content is rejected" do
    project = make_project
    file = Tempfile.new(["shot", ".png"])
    file.binmode
    file.write(Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aGNcAAAAASUVORK5CYII="))
    file.flush
    upload = Rack::Test::UploadedFile.new(file.path, "image/png")
    post "/api/widget/#{project.public_key}/annotations", params: feedback_params(project, screenshot: upload), headers: widget_headers(project)
    assert_response :created
    note = project.annotations.last
    assert File.exist?(ScreenshotStore.root.join(note.screenshot_key))
    get "/api/projects/#{project.id}/annotations/#{note.id}/screenshot"
    assert_response :unauthorized
    sign_in
    get "/api/projects/#{project.id}/annotations/#{note.id}/screenshot"
    assert_response :success
    assert_equal "image/png", response.media_type
    file.rewind; file.truncate(0); file.write("<script>alert(1)</script>"); file.flush
    post "/api/widget/#{project.public_key}/annotations", params: feedback_params(project, screenshot: Rack::Test::UploadedFile.new(file.path, "image/png")), headers: widget_headers(project)
    assert_response :unprocessable_entity
    assert_equal 1, project.annotations.count
  ensure
    ScreenshotStore.delete(note&.screenshot_key)
    file&.close!
  end
end
