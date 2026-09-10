class AnnotationsController < ApplicationController
  before_action :set_project
  rescue_from AnnotationFilter::Invalid do |error|
    render json: { error: error.message }, status: :unprocessable_entity
  end

  def index
    scope = AnnotationFilter.apply(@project.annotations, params).order(created_at: :desc, id: :desc)
    page = [params[:number].to_i, 1].max
    render json: { items: scope.offset((page - 1) * 30).limit(30).map(&:as_feedback), total: scope.count, pages: @project.annotations.distinct.order(:page_url).pluck(:page_url), authors: @project.annotations.distinct.order(:author_name).pluck(:author_name), number: page }
  end

  def show
    render json: @project.annotations.find(params[:id]).as_feedback(detail: true)
  end

  def export
    response.headers["Cache-Control"] = "private, no-store"
    scope = AnnotationFilter.apply(@project.annotations, params)
    send_data AnnotationCsv.generate(@project, base_url: ENV.fetch("APP_URL"), annotations: scope),
      type: "text/csv; charset=utf-8", disposition: "attachment",
      filename: "webnotator-#{@project.id}-anotaciones.csv"
  end

  def update
    annotation = @project.annotations.find(params[:id])
    annotation.update!(params.require(:annotation).permit(:status))
    render json: annotation.as_feedback(detail: true)
  end

  def bulk_update
    ids = params[:ids]
    unless ids.is_a?(Array) && ids.size.between?(1, 100) && ids.all? { |id| id.to_s.match?(/\A[1-9]\d*\z/) } && Annotation::STATUSES.include?(params[:status])
      render json: { error: "Seleccioná entre 1 y 100 anotaciones y un estado válido" }, status: :unprocessable_entity
      return
    end
    Annotation.transaction do
      notes = @project.annotations.where(id: ids.uniq).lock.to_a
      raise ActiveRecord::RecordNotFound unless notes.size == ids.map(&:to_i).uniq.size
      notes.each { |note| note.update!(status: params[:status]) }
      render json: { updated: notes.size }
    end
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
