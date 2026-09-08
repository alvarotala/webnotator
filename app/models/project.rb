class Project < ApplicationRecord
  has_many :annotations, dependent: :restrict_with_error
  before_validation :assign_tokens, on: :create
  validates :name, presence: true, length: { maximum: 100 }
  validates :public_key, :invite_token, presence: true, uniqueness: true
  validate :valid_origins

  def allows?(origin)
    origins.include?(origin)
  end

  private

  def assign_tokens
    self.public_key ||= SecureRandom.uuid
    self.invite_token ||= SecureRandom.urlsafe_base64(32)
  end

  def valid_origins
    unless origins.is_a?(Array) && origins.size.between?(1, 20) && origins.all? { |origin| valid_origin?(origin) }
      errors.add(:origins, "usa entre 1 y 20 orígenes completos, por ejemplo https://agendario.app, sin rutas ni / final")
    end
  end

  def valid_origin?(value)
    uri = URI.parse(value)
    %w[http https].include?(uri.scheme) && uri.host.present? && uri.userinfo.nil? && uri.path.empty? && uri.query.nil? && uri.fragment.nil? && value == "#{uri.scheme}://#{uri.host}#{uri.port == uri.default_port ? '' : ":#{uri.port}"}"
  rescue URI::InvalidURIError, TypeError
    false
  end
end
