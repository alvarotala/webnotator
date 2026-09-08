class SessionsController < ApplicationController
  skip_before_action :require_admin, only: [:show, :create]
  rate_limit to: 10, within: 1.minute, only: :create, with: -> { render json: { error: "Demasiados intentos. Esperá un minuto." }, status: :too_many_requests }

  def show
    admin = Admin.find_by(id: session[:admin_id]) if session[:expires_at].to_i > Time.current.to_i
    response.headers["Cache-Control"] = "no-store"
    render json: { admin: admin&.as_json(only: [:email]), csrf_token: form_authenticity_token }
  end

  def create
    admin = Admin.find_by(email: params[:email].to_s.strip.downcase)
    if admin&.authenticate(params[:password].to_s)
      reset_session
      session[:admin_id] = admin.id
      session[:expires_at] = 12.hours.from_now.to_i
      render json: { admin: { email: admin.email }, csrf_token: form_authenticity_token }
    else
      render json: { error: "Email o contraseña incorrectos" }, status: :unauthorized
    end
  end

  def destroy
    reset_session
    render json: { csrf_token: form_authenticity_token }
  end
end
