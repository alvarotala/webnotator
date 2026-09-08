class Annotation < ApplicationRecord
  KINDS = %w[bug change suggestion].freeze
  STATUSES = %w[pending in_progress resolved discarded].freeze
  belongs_to :project
  validates :author_name, presence: true, length: { maximum: 80 }
  validates :body, presence: true, length: { maximum: 10_000 }
  validates :page_url, presence: true, length: { maximum: 2048 }
  validates :page_title, length: { maximum: 200 }
  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :client_id, format: { with: /\A[\w-]{16,80}\z/ }, uniqueness: { scope: :project_id }
  validate :page_belongs_to_project, if: -> { new_record? || will_save_change_to_page_url? }
  validate :context_limits

  def as_feedback(detail: false)
    data = as_json(only: %i[id author_name kind status body page_url page_title element viewport created_at updated_at])
    data["screenshot_url"] = screenshot_key.present? ? "/api/projects/#{project_id}/annotations/#{id}/screenshot" : nil
    data
  end

  private

  def page_belongs_to_project
    uri = URI.parse(page_url.to_s)
    origin = "#{uri.scheme}://#{uri.host}#{uri.port == uri.default_port ? '' : ":#{uri.port}"}"
    errors.add(:page_url, "no pertenece a los sitios del proyecto") unless project && project.allows?(origin) && uri.userinfo.nil? && uri.query.nil?
  rescue URI::InvalidURIError
    errors.add(:page_url, "no es válida")
  end

  def context_limits
    errors.add(:element, "no es válido") unless element.is_a?(Hash) && element.values.all? { |v| v.is_a?(String) } && element.to_json.bytesize <= 4000
    errors.add(:viewport, "no es válido") unless viewport.is_a?(Hash) && viewport.values.all? { |v| v.is_a?(Integer) && v.between?(0, 20_000) }
  end
end
