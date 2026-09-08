class Admin < ApplicationRecord
  has_secure_password
  normalizes :email, with: ->(email) { email.strip.downcase }
  validates :email, presence: true, uniqueness: true
  validates :password, length: { minimum: 12 }, if: -> { password.present? }
end
