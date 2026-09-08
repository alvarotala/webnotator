class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  before_action :require_admin
  before_action -> { response.headers["Cache-Control"] = "no-store" }
  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: "No encontrado" }, status: :not_found
  end
  rescue_from ActiveRecord::RecordInvalid do |error|
    render json: { error: error.record.errors.full_messages.join(". ") }, status: :unprocessable_entity
  end
  rescue_from ActionController::InvalidAuthenticityToken do
    render json: { error: "La sesión venció. Recargá la página." }, status: :unprocessable_entity
  end

  private

  def require_admin
    @current_admin = Admin.find_by(id: session[:admin_id]) if session[:expires_at].to_i > Time.current.to_i
    render json: { error: "Iniciá sesión para continuar" }, status: :unauthorized unless @current_admin
  end
end
