# == Schema Information
#
# Table name: users
#
#  id                     :integer          not null, primary key
#  first_name             :string(60)
#  last_name              :string(60)
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  reset_password_token   :string
#  reset_password_sent_at :datetime
#  remember_created_at    :datetime
#  sign_in_count          :integer          default(0), not null
#  current_sign_in_at     :datetime
#  last_sign_in_at        :datetime
#  current_sign_in_ip     :string
#  last_sign_in_ip        :string
#  failed_attempts        :integer          default(0), not null
#  unlock_token           :string
#  locked_at              :datetime
#  super_admin            :boolean          default(FALSE), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  active                 :boolean          default(TRUE), not null
#

# Encoding: utf-8

# User model
class User < ActiveRecord::Base
  obfuscate_id

  has_many :app_events
  has_many :user_permissions, dependent: :destroy
  has_many :accounts, through: :user_permissions

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :lockable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  validates :email, length: { maximum: 255 }, presence: true
  validates :first_name, length: { maximum: 60 }, presence: true, allow_blank: true
  validates :last_name, length: { maximum: 60 }, presence: true
  validates :password, confirmation: true, presence: true, on: :create
  validates :super_admin, inclusion: { in: [true, false] }, presence: false, allow_blank: false

  def active_for_authentication?
    super && active?
  end

  def inactive_message
    'Account is inactive'
  end

  def to_s
    if first_name.empty?
      if last_name.empty?
        '(unknown)'
      else
        last_name
      end
    else
      if last_name.empty?
        first_name
      else
        first_name + ' ' + last_name
      end
    end
  end
end
