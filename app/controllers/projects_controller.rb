class ProjectsController < ApplicationController
  def index
    render json: Project.order(created_at: :asc).map { |p| serialize(p) }
  end

  def create
    project = Project.create!(project_params)
    render json: serialize(project), status: :created
  end

  def update
    project = Project.find(params[:id])
    project.update!(project_params)
    render json: serialize(project)
  end

  def rotate_invitation
    project = Project.find(params[:id])
    project.update!(invite_token: SecureRandom.urlsafe_base64(32))
    render json: serialize(project)
  end

  private

  def project_params
    params.require(:project).permit(:name, origins: [])
  end

  def serialize(project)
    project.as_json(only: [:id, :name, :public_key, :origins]).merge(
      invitation_url: "#{ENV.fetch('APP_URL')}/invite/#{project.invite_token}",
      counts: project.annotations.group(:status).count,
      total: project.annotations.where.not(status: "discarded").count
    )
  end
end
