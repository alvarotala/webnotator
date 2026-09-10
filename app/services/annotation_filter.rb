class AnnotationFilter
  class Invalid < StandardError; end

  def self.apply(scope, params)
    statuses = Array(params[:status]).reject(&:blank?)
    statuses = [] if statuses == ["all"]
    raise Invalid, "Estado no válido" unless (statuses - Annotation::STATUSES).empty?
    scope = statuses.empty? ? scope.where.not(status: "discarded") : scope.where(status: statuses)
    if params[:kind].present?
      raise Invalid, "Tipo no válido" unless Annotation::KINDS.include?(params[:kind])
      scope = scope.where(kind: params[:kind])
    end
    scope = scope.where(page_url: params[:page]) if params[:page].present?
    scope = scope.where(author_name: params[:author]) if params[:author].present?
    from = parse_date(params[:from])
    to = parse_date(params[:to])
    raise Invalid, "La fecha inicial debe ser anterior o igual a la final" if from && to && from > to
    scope = scope.where("created_at >= ?", Time.utc(from.year, from.month, from.day)) if from
    scope = scope.where("created_at < ?", Time.utc(to.year, to.month, to.day) + 1.day) if to
    if params[:q].present?
      query = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.first(200))}%"
      scope = scope.where("body ILIKE :q OR author_name ILIKE :q OR page_title ILIKE :q", q: query)
    end
    scope
  end

  def self.parse_date(value)
    return if value.blank?
    raise Invalid, "Usá fechas válidas con formato AAAA-MM-DD" unless value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}\z/)
    Date.iso8601(value)
  rescue Date::Error
    raise Invalid, "La fecha no es válida"
  end
  private_class_method :parse_date
end
