class InvitationsController < ApplicationController
  skip_before_action :require_admin
  def show
    response.headers["Cache-Control"] = "no-store"
    project = Project.find_by!(invite_token: params[:token])
    render json: project.as_json(only: [:name, :public_key, :origins])
  end
end
