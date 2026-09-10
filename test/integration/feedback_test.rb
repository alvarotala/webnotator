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

  test "site rules reject malformed domains and URLs with paths" do
    sign_in
    [[], ["com"], ["*.agendario.app"], ["agendario.app/path"], ["agendario.app:8080"], ["agendario..app"], ["-agendario.app"], ["https://agendario.app/path"], ["https://agendario.app/"], ["javascript:alert(1)"], ["https://user:pass@agendario.app"]].each do |origins|
      post "/api/projects", params: {project: {name: "Test", origins: origins}}, as: :json, headers: csrf_headers
      assert_response :unprocessable_entity
    end
  end

  test "bare domain permits root and nested subdomains with exact CORS responses" do
    sign_in
    post "/api/projects", params: {project: {name: "Agendario", origins: [" Agendario.APP "]}}, as: :json, headers: csrf_headers
    assert_response :created
    project = Project.last
    assert_equal ["agendario.app"], project.origins

    ["https://agendario.app", "https://admin.agendario.app", "https://preview.admin.agendario.app", "http://beta.agendario.app:8080"].each do |origin|
      options "/api/widget/#{project.public_key}/context", headers: {"Origin" => origin}
      assert_response :no_content
      assert_equal origin, response.headers["Access-Control-Allow-Origin"]
      get "/api/widget/#{project.public_key}/context", headers: {"Origin" => origin, "Authorization" => "Bearer #{project.invite_token}"}
      assert_response :success
      assert_equal "agendario.app", response.parsed_body["activation_domain"]
      post "/api/widget/#{project.public_key}/annotations", params: feedback_params(project, page_url: "#{origin}/plataforma"), headers: {"Origin" => origin, "Authorization" => "Bearer #{project.invite_token}"}
      assert_response :created
    end

    ["https://evilagendario.app", "https://agendario.app.evil.com", "https://agendario.com", "https://agendario.app@evil.com", "null"].each do |origin|
      options "/api/widget/#{project.public_key}/context", headers: {"Origin" => origin}
      assert_response :forbidden
      assert_nil response.headers["Access-Control-Allow-Origin"]
    end
    assert_equal 4, project.annotations.count
  end

  test "complete origins keep their scheme hostname and port restrictions" do
    project = make_project("Exact", "https://admin.agendario.app:8443")
    assert project.allows?("https://admin.agendario.app:8443")
    assert_nil project.activation_domain("https://admin.agendario.app:8443")
    ["https://admin.agendario.app", "http://admin.agendario.app:8443", "https://sub.admin.agendario.app:8443", "https://agendario.app:8443"].each do |origin|
      assert_not project.allows?(origin)
    end
  end

  test "shared activation domain is only returned after invitation authentication" do
    project = make_project("Agendario", "agendario.app")
    get "/api/widget/#{project.public_key}/context", headers: {"Origin" => "https://admin.agendario.app"}
    assert_response :unauthorized
    assert_nil response.parsed_body["activation_domain"]
    assert_nil project.activation_domain("https://evilagendario.app")
    assert_nil project.activation_domain("https://agendario.app.evil.com")
    assert_nil project.activation_domain("null")
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

  test "CSV export requires admin and includes all matching project notes across pagination" do
    project = make_project
    32.times do |index|
      project.annotations.create!(author_name: "María", body: "Comentario #{index}", kind: "change",
        status: index.even? ? "resolved" : "pending", page_url: "#{project.origins.first}/pagina-#{index}", client_id: SecureRandom.uuid)
    end
    other = make_project("Otro proyecto")
    other.annotations.create!(author_name: "Ana", body: "OTRO_PROYECTO_NO_EXPORTAR", kind: "bug", page_url: "#{other.origins.first}/", client_id: SecureRandom.uuid)
    get "/api/projects/#{project.id}/annotations/export"
    assert_response :unauthorized
    sign_in
    get "/api/projects/#{project.id}/annotations/export", params: {number: 2}
    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_includes response.headers["Content-Disposition"], "attachment"
    assert_includes response.headers["Cache-Control"], "no-store"
    assert response.body.start_with?("\uFEFF")
    assert_equal 33, response.body.lines.size
    assert_includes response.body, '"Comentario 0"'
    assert_includes response.body, '"Comentario 31"'
    assert_includes response.body, '"María"'
    assert_includes response.body, '"Pendiente"'
    assert_includes response.body, '"Resuelto"'
    assert_not_includes response.body, "OTRO_PROYECTO_NO_EXPORTAR"
  end

  test "CSV export preserves quoted multiline feedback and escapes spreadsheet formulas" do
    project = make_project
    note = project.annotations.create!(author_name: "=1+1", body: "Cambiar \"título\", por otro\nSegunda línea", kind: "suggestion",
      page_url: "#{project.origins.first}/agenda", client_id: SecureRandom.uuid,
      element: {selector: "#titulo", tag: "h1", text: "@elemento"}, viewport: {width: 1280, height: 800}, screenshot_key: "example.png")
    sign_in
    get "/api/projects/#{project.id}/annotations/export"
    assert_response :success
    assert_includes response.body, %Q{"'=1+1"}
    assert_includes response.body, %Q{"'@elemento"}
    assert_includes response.body, %Q{"Cambiar ""título"", por otro\nSegunda línea"}
    assert_includes response.body, "#{ENV.fetch('APP_URL')}/api/projects/#{project.id}/annotations/#{note.id}/screenshot"
    assert_includes response.body, '"#titulo","h1"'
    assert_includes response.body, '"1280","800"'
  end

  test "CSV export of an empty project contains headers" do
    project = make_project
    sign_in
    get "/api/projects/#{project.id}/annotations/export"
    assert_response :success
    assert_equal 1, response.body.lines.size
    assert_includes response.body, '"Anotación"'
  end

  test "ignored annotations are excluded by default from list exports and project total" do
    project = make_project
    active = create_note(project, body: "VISIBLE")
    ignored = create_note(project, status: "discarded", body: "IGNORADA")
    sign_in
    [nil, "", "all"].each do |status|
      get "/api/projects/#{project.id}/annotations", params: {status: status}
      assert_equal [active.id], response.parsed_body["items"].map { |note| note["id"] }
      assert_equal 1, response.parsed_body["total"]
    end
    get "/api/projects"
    assert_equal 1, response.parsed_body.find { |item| item["id"] == project.id }["total"]
    get "/api/projects/#{project.id}/annotations/export"
    assert_includes response.body, '"VISIBLE"'
    assert_not_includes response.body, '"IGNORADA"'
    get "/api/projects/#{project.id}/annotations", params: {status: "discarded"}
    assert_equal [ignored.id], response.parsed_body["items"].map { |note| note["id"] }
    get "/api/projects/#{project.id}/annotations/export", params: {status: ["pending", "discarded"]}
    assert_includes response.body, '"VISIBLE"'
    assert_includes response.body, '"IGNORADA"'
    assert_includes response.body, '"Ignorada"'
  end

  test "export combines statuses author inclusive UTC dates type page and search without pagination" do
    project = make_project
    attrs = {author_name: "María", kind: "bug", page_url: "#{project.origins.first}/agenda", body: "REVISAR FECHA"}
    start = Time.utc(2026, 9, 1)
    finish = Time.utc(2026, 9, 2, 23, 59, 59)
    31.times { create_note(project, **attrs, created_at: start) }
    create_note(project, **attrs, status: "resolved", created_at: finish)
    [ {created_at: start - 1.second}, {created_at: finish + 1.second}, {author_name: "Ana"}, {kind: "change"},
      {page_url: "#{project.origins.first}/otra"}, {body: "OTRO TEXTO"}, {status: "discarded"} ].each do |override|
      create_note(project, **attrs.merge(created_at: start).merge(override))
    end
    sign_in
    filters = {status: ["pending", "resolved"], author: "María", kind: "bug", page: attrs[:page_url], q: "revisar", from: "2026-09-01", to: "2026-09-02", number: 2}
    get "/api/projects/#{project.id}/annotations", params: filters
    assert_response :success
    assert_equal 32, response.parsed_body["total"]
    assert_equal 2, response.parsed_body["items"].size
    assert_equal ["Ana", "María"], response.parsed_body["authors"]
    get "/api/projects/#{project.id}/annotations/export", params: filters
    assert_response :success
    assert_equal 33, response.body.lines.size
    assert_includes response.body, finish.iso8601
    get "/api/projects/#{project.id}/annotations/export", params: filters.merge(q: "sin coincidencias")
    assert_equal 1, response.body.lines.size
  end

  test "invalid export and listing filters return helpful errors" do
    project = make_project
    sign_in
    [{from: "2026-02-30"}, {to: "invalid"}, {from: "2026-09-03", to: "2026-09-01"}, {status: ["unknown"]}, {kind: "unknown"}].each do |filters|
      ["", "/export"].each do |suffix|
        get "/api/projects/#{project.id}/annotations#{suffix}", params: filters
        assert_response :unprocessable_entity
        assert response.parsed_body["error"].present?
      end
    end
  end

  test "bulk status updates require authentication CSRF valid input and complete project membership" do
    project = make_project
    notes = 2.times.map { create_note(project) }
    untouched = create_note(project)
    foreign = create_note(make_project("Otro"))
    endpoint = "/api/projects/#{project.id}/annotations/bulk_update"
    patch endpoint, params: {ids: notes.map(&:id), status: "resolved"}, as: :json
    assert_response :unprocessable_entity
    get "/api/session"
    patch endpoint, params: {ids: notes.map(&:id), status: "resolved"}, as: :json, headers: {"X-CSRF-Token" => response.parsed_body["csrf_token"]}
    assert_response :unauthorized
    sign_in
    [[], [notes[0].id, foreign.id], [notes[0].id, 0], [notes[0].id, 999999999], Array.new(101, notes[0].id)].each do |ids|
      patch endpoint, params: {ids: ids, status: "resolved"}, as: :json, headers: csrf_headers
      assert_includes [404, 422], response.status
      assert_equal ["pending"], notes.map { |note| note.reload.status }.uniq
    end
    patch endpoint, params: {ids: notes.map(&:id), status: "unknown"}, as: :json, headers: csrf_headers
    assert_response :unprocessable_entity
    patch endpoint, params: {ids: notes.map(&:id), status: "discarded"}, as: :json, headers: csrf_headers
    assert_response :success
    assert_equal 2, response.parsed_body["updated"]
    assert_equal ["discarded"], notes.map { |note| note.reload.status }.uniq
    assert_equal "pending", untouched.reload.status
    assert_equal "pending", foreign.reload.status
    patch endpoint, params: {ids: notes.map(&:id), status: "pending"}, as: :json, headers: csrf_headers
    assert_response :success
    assert_equal ["pending"], notes.map { |note| note.reload.status }.uniq
  end

  private

  def create_note(project, **attrs)
    project.annotations.create!({author_name: "Ana", body: "Revisar", kind: "change", page_url: "#{project.origins.first}/", client_id: SecureRandom.uuid}.merge(attrs))
  end

end
