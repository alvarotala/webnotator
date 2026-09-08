class WidgetController < ActionController::API
  before_action :find_project
  before_action :allow_origin
  before_action :authenticate_invitation, except: :preflight
  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: "La invitación ya no está disponible" }, status: :not_found
  end
  rescue_from ActiveRecord::RecordInvalid do |error|
    render json: { error: error.record.errors.full_messages.join(". ") }, status: :unprocessable_entity
  end
  rescue_from ScreenshotStore::Invalid, JSON::ParserError do |error|
    render json: { error: error.is_a?(ScreenshotStore::Invalid) ? error.message : "Contexto inválido" }, status: :unprocessable_entity
  end

  def preflight
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Authorization, Content-Type"
    response.headers["Access-Control-Max-Age"] = "600"
    head :no_content
  end

  def context
    render json: { name: @project.name, activation_domain: @project.activation_domain(@widget_origin) }
  end

  def show
    note = @project.annotations.find(params[:id])
    render json: note.as_json(only: [:element, :page_url])
  end

  def create
    existing = @project.annotations.find_by(client_id: params[:client_id])
    return render json: { id: existing.id }, status: :ok if existing
    annotation = @project.annotations.new(params.permit(:author_name, :kind, :body, :page_url, :page_title, :client_id))
    element = JSON.parse(params[:element].presence || "{}")
    viewport = JSON.parse(params[:viewport].presence || "{}")
    unless element.is_a?(Hash) && viewport.is_a?(Hash)
      return render json: { error: "Contexto inválido" }, status: :unprocessable_entity
    end
    annotation.element = element.slice("selector", "tag", "text")
    annotation.viewport = viewport.slice("width", "height")
    annotation.validate!
    key = nil
    begin
      if params[:screenshot].present?
        key, type = ScreenshotStore.write(params[:screenshot])
        annotation.screenshot_key = key
        annotation.screenshot_type = type
      end
      annotation.save!
    rescue ActiveRecord::RecordNotUnique
      ScreenshotStore.delete(key)
      return render json: { id: @project.annotations.find_by!(client_id: params[:client_id]).id }
    rescue StandardError
      ScreenshotStore.delete(key)
      raise
    end
    render json: { id: annotation.id }, status: :created
  end

  private

  def find_project
    @project = Project.find_by!(public_key: params[:project_key])
    response.headers["Cache-Control"] = "no-store"
  end

  def allow_origin
    # Same-origin GET requests may omit Origin; bearer authentication is still required.
    origin = request.headers["Origin"].presence || (request.get? ? request.base_url : nil)
    unless @project.allows?(origin)
      render json: { error: "Este sitio no está autorizado para el proyecto" }, status: :forbidden
      return
    end
    response.headers["Access-Control-Allow-Origin"] = origin
    response.headers["Vary"] = "Origin"
    @widget_origin = origin
  end

  def authenticate_invitation
    token = request.headers["Authorization"].to_s.delete_prefix("Bearer ")
    unless ActiveSupport::SecurityUtils.secure_compare(@project.invite_token, token)
      render json: { error: "La invitación venció. Pedí un enlace nuevo." }, status: :unauthorized
    end
  end
end
