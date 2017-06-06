class DeviseInvitations::Invitation < ActiveRecord::Base
  belongs_to :sent_by, class_name: 'User', foreign_key: 'sent_by_id'
  has_secure_token :token

  validates :email, presence: true, format: { with: Devise.email_regexp }
  validates :email, :sent_by, uniqueness: { scope: [:email, :sent_by] }
  validate :presence_as_user, on: :create

  enum status: [:pending, :accepted, :ignored]

  after_create do
    buyer_profile = BuyerProfile.find(self.profile_id)
    DeviseInvitations::Mailer.delay.instructions(self, buyer_profile)
  end

  private

  def presence_as_user
    errors.add(:email, :user_already_exists) if User.exists?(email: email)
  end
end
