class AnnotationsController < ApplicationController
  before_action :set_project

  def index
    scope = @project.annotations.order(created_at: :desc)
    scope = scope.where(status: params[:status]) if params[:status].present?
    scope = scope.where(kind: params[:kind]) if params[:kind].present?
    scope = scope.where(page_url: params[:page]) if params[:page].present?
    if params[:q].present?
      query = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.first(200))}%"
      scope = scope.where("body ILIKE :q OR author_name ILIKE :q OR page_title ILIKE :q", q: query)
    end
    page = [params[:number].to_i, 1].max
    render json: { items: scope.offset((page - 1) * 30).limit(30).map(&:as_feedback), total: scope.count, pages: @project.annotations.distinct.order(:page_url).pluck(:page_url), number: page }
  end

  def show
    render json: @project.annotations.find(params[:id]).as_feedback(detail: true)
  end

  def export
    response.headers["Cache-Control"] = "private, no-store"
    send_data AnnotationCsv.generate(@project, base_url: ENV.fetch("APP_URL")),
      type: "text/csv; charset=utf-8", disposition: "attachment",
      filename: "webnotator-#{@project.id}-anotaciones.csv"
  end

  def update
    annotation = @project.annotations.find(params[:id])
    annotation.update!(params.require(:annotation).permit(:status))
    render json: annotation.as_feedback(detail: true)
  end

  def screenshot
    annotation = @project.annotations.find(params[:id])
    raise ActiveRecord::RecordNotFound unless annotation.screenshot_key
    response.headers["Cache-Control"] = "private, no-store"
    send_file ScreenshotStore.root.join(annotation.screenshot_key), type: annotation.screenshot_type, disposition: "inline"
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end
end
