# == Schema Information
#
# Table name: user_permissions
#
#  id            :integer          not null, primary key
#  user_id       :integer          not null
#  account_id    :integer          not null
#  account_admin :boolean          default(FALSE), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#

# User Permission model
class UserPermission < ActiveRecord::Base
  obfuscate_id

  belongs_to :user
  belongs_to :account

  delegate :email, to: :user, prefix: true

  validates :account_admin, inclusion: { in: [true, false] }, presence: false, allow_blank: false
  validates :account_id, presence: true
  validates :user_id, uniqueness: { scope: :account_id }, presence: true
end
