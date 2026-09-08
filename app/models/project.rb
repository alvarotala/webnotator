class Project < ApplicationRecord
  has_many :annotations, dependent: :restrict_with_error
  before_validation :assign_tokens, on: :create
  before_validation :normalize_origins
  validates :name, presence: true, length: { maximum: 100 }
  validates :public_key, :invite_token, presence: true, uniqueness: true
  validate :valid_origins

  def allows?(origin)
    return false unless valid_origin?(origin)

    host = URI.parse(origin).host.downcase
    origins.any? do |rule|
      if domain_rule?(rule)
        host == rule || host.end_with?(".#{rule}")
      else
        rule == origin
      end
    end
  end

  def activation_domain(origin)
    return unless valid_origin?(origin)

    host = URI.parse(origin).host.downcase
    origins.select { |rule| domain_rule?(rule) && (host == rule || host.end_with?(".#{rule}")) }.min_by(&:length)
  end

  private

  def assign_tokens
    self.public_key ||= SecureRandom.uuid
    self.invite_token ||= SecureRandom.urlsafe_base64(32)
  end

  def valid_origins
    unless origins.is_a?(Array) && origins.size.between?(1, 20) && origins.all? { |rule| domain_rule?(rule) || valid_origin?(rule) }
      errors.add(:origins, "usa entre 1 y 20 dominios (agendario.app) o sitios específicos (https://admin.agendario.app), sin rutas")
    end
  end

  def normalize_origins
    return unless origins.is_a?(Array)

    self.origins = origins.map { |rule| rule.is_a?(String) ? rule.strip.downcase : rule }.uniq
  end

  def domain_rule?(value)
    return false unless value.is_a?(String) && value.length <= 253

    # A dot boundary prevents agendario.app from matching evilagendario.app.
    value.match?(/\A(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z](?:[a-z0-9-]{0,61}[a-z0-9])?\z/)
  end

  def valid_origin?(value)
    return false unless value.is_a?(String)

    uri = URI.parse(value)
    %w[http https].include?(uri.scheme) && uri.host.present? && uri.userinfo.nil? && uri.path.empty? && uri.query.nil? && uri.fragment.nil? && value == "#{uri.scheme}://#{uri.host}#{uri.port == uri.default_port ? '' : ":#{uri.port}"}"
  rescue URI::InvalidURIError, TypeError
    false
  end
end
