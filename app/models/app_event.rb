# == Schema Information
#
# Table name: app_events
#
#  id         :integer          not null, primary key
#  account_id :integer
#  user_id    :integer
#  level      :string(10)       default("info"), not null
#  message    :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

# Encoding: utf-8

# App Event model
class AppEvent < ActiveRecord::Base
  belongs_to :account
  belongs_to :user

  validates :account_id, numericality: { integer_only: true }, allow_nil: true
  validates :level, inclusion: { in: %w( success info warning alert ) }, presence: true
  validates :message, length: { maximum: 255 }, presence: true
  validates :user_id, numericality: { integer_only: true }, allow_nil: true

  def self.success(message, account = nil, user = nil)
    AppEvent.create(level: 'success', message: message, account: account, user: user)
  end

  def self.info(message, account = nil, user = nil)
    AppEvent.create(level: 'info', message: message, account: account, user: user)
  end

  def self.warning(message, account = nil, user = nil)
    AppEvent.create(level: 'warning', message: message, account: account, user: user)
  end

  def self.alert(message, account = nil, user = nil)
    AppEvent.create(level: 'alert', message: message, account: account, user: user)
  end
end
