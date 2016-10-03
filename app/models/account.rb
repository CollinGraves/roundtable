# == Schema Information
#
# Table name: accounts
#
#  id                       :integer          not null, primary key
#  company_name             :string(255)      not null
#  email                    :string(255)      not null
#  plan_id                  :integer          not null
#  paused_plan_id           :integer
#  active                   :boolean          default(TRUE), not null
#  address_line1            :string(120)
#  address_line2            :string(120)
#  address_city             :string(120)
#  address_zip              :string(20)
#  address_state            :string(60)
#  address_country          :string(2)
#  card_token               :string(60)
#  stripe_customer_id       :string(60)
#  stripe_subscription_id   :string(60)
#  cancellation_message     :string
#  cancelled_at             :datetime
#  expires_at               :datetime
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  hostname                 :string(255)
#  subdomain                :string(64)
#  custom_path              :string(60)
#  card_brand               :string(25)
#  card_last4               :string(4)
#  card_exp                 :string(7)
#  cancellation_category_id :integer
#  cancellation_reason_id   :integer
#

# Account model
class Account < ActiveRecord::Base
  obfuscate_id

  belongs_to :plan
  belongs_to :paused_plan, class_name: 'Plan'
  belongs_to :cancellation_category
  belongs_to :cancellation_reason

  has_many :app_events, dependent: :destroy
  has_many :invoices, dependent: :destroy
  has_many :users, through: :user_permissions
  has_many :user_invitations, dependent: :destroy
  has_many :user_permissions, dependent: :destroy

  delegate :currency, :allow_custom_path, :allow_hostname, :allow_subdomain, :stripe_id, to: :plan, prefix: true
  delegate :stripe_id, to: :paused_plan, prefix: true, allow_nil: true

  accepts_nested_attributes_for :users

  default_scope { order('company_name ASC') }

  before_validation do |account|
    unless account.plan.nil?
      account.custom_path = nil unless account.plan_allow_custom_path
      account.hostname = nil unless account.plan_allow_hostname
      account.subdomain = nil unless account.plan_allow_subdomain
    end
  end

  validates :active, inclusion: { in: [true, false] }, presence: false, allow_blank: false
  validates :address_city, length: { maximum: 120 }
  validates :address_country, length: { maximum: 2 }
  validates :address_line1, length: { maximum: 120 }
  validates :address_line2, length: { maximum: 120 }
  validates :address_state, length: { maximum: 60 }
  validates :address_zip, length: { maximum: 20 }
  validates :cancellation_category_id, presence: true, if: '!cancelled_at.nil?'
  validates :cancellation_message, length: { maximum: 255 }
  validates :cancellation_message, presence: true, if: :require_cancellation_message
  validates :cancellation_reason_id, presence: true, if: :require_cancellation_reason_id
  validates :card_token, length: { maximum: 60 }
  validates :card_token, presence: true, if: 'plan_id? && plan.require_card_upfront'
  validates :company_name, length: { maximum: 255 }, presence: true
  validates :custom_path, length: { in: 2..60 }, allow_nil: true
  validates :custom_path, uniqueness: true, unless: 'custom_path.nil?'
  validates :custom_path,
            format: { with: /\A[a-z0-9]+\Z/i, message: 'can only contain letters and numbers' },
            unless: 'custom_path.nil?'
  validates :custom_path,
            format: { with: /\A.*[a-z].*\Z/i, message: 'must contain at least one letter' },
            unless: 'custom_path.nil?'
  validates :email, length: { maximum: 255 }, presence: true
  validates :hostname, length: { maximum: 255 }
  validates :hostname,
            format: { with: /\A([a-z0-9]+[a-z0-9\-]*)((\.([a-z0-9]+[a-z0-9\-]*))+)\Z/i },
            uniqueness: true,
            unless: 'hostname.nil?'
  validates :paused_plan_id, numericality: { integer_only: true }, allow_nil: true
  validates :plan_id, numericality: { integer_only: true }, presence: true
  validates :stripe_customer_id, length: { maximum: 60 }
  validates :stripe_subscription_id, length: { maximum: 60 }
  validates :subdomain, length: { maximum: 64 }
  validates :subdomain,
            format: { with: /\A([a-z0-9]+[a-z0-9\-]*)\Z/i },
            uniqueness: true,
            unless: 'subdomain.nil?'
  validates_associated :users, on: :create

  def require_cancellation_reason_id
    return false if cancelled_at.nil?
    return false if cancellation_category.nil?
    return true if cancellation_category.cancellation_reasons.available.count > 0
    false
  end

  def require_cancellation_message
    return false if cancelled_at.nil?
    return true if cancellation_category_id? && cancellation_category.require_message
    return true if cancellation_reason_id? && cancellation_reason.require_message
    false
  end

  def to_s
    company_name
  end

  def address_country_name
    c = Country[address_country]
    if c.nil?
      address_country
    else
      c.name
    end
  end

  def cancel(params)
    time = Time.zone.now
    params[:cancelled_at] = time.strftime('%Y-%m-%d %H:%M:%S')
    params[:active] = false
    update_attributes(params)
  end

  def self.find_account(path, host, subdomain)
    if path
      # Assume that they're using http://www.example.com/ACCOUNT
      @current_account = Account.find_by_path!(path)
    else
      # Try http://ACCOUNT/ then http://ACCOUNT.example.com/
      @current_account = Account.find_by_hostname(host)
      @current_account = Account.find_by_subdomain(subdomain) if @current_account.nil?
    end

    @current_account
  end

  def self.find_by_hostname(hostname)
    Account.joins(:plan).find_by plans: { allow_hostname: true }, active: true, hostname: hostname
  end

  def self.find_by_path(path)
    if path.match(/\A[0-9]+\Z/)
      path = Account.deobfuscate_id(path.to_i) unless path.nil?
      Account.joins(:plan).find_by active: true, id: path
    else
      Account.joins(:plan).find_by plans: { allow_custom_path: true }, active: true, custom_path: path
    end
  end

  def self.find_by_path!(path)
    account = Account.find_by_path(path)
    fail ActiveRecord::RecordNotFound if account.nil?
    account
  end

  def self.find_by_subdomain(subdomain)
    Account.joins(:plan).find_by plans: { allow_subdomain: true }, active: true, subdomain: subdomain
  end

  def pause
    return false if plan.paused_plan_id.nil?

    update_attributes(paused_plan_id: plan.paused_plan_id)
  end

  # rubocop:disable PerceivedComplexity, Metrics/CyclomaticComplexity
  def register(current_user)
    # Set the email from the current_user or the first user
    if email.blank?
      if users && users[0]
        self.email = users[0].email unless users[0].nil?
        logger.debug 'Using the first users email as the accounts email'
      else
        if current_user
          self.email = current_user.email
          logger.debug 'Using the current users email as the accounts email'
        end
      end
    end

    if save
      # Add the current_user as an account admin or set all users as an account admin
      if current_user && (user_permissions.count == 0)
        user_permissions.build(user: current_user, account_admin: true).save!
        logger.debug { "Making the current user an admin for #{self}" }
      else
        admin_all_users
        logger.debug { "Making all users an admin for #{self}" }
      end
      return true
    end

    false
  end
  # rubocop:enable PerceivedComplexity, Metrics/CyclomaticComplexity

  def restore
    params = { cancellation_category: nil,
               cancellation_reason: nil,
               cancellation_message: nil,
               cancelled_at: nil,
               active: true }
    update_attributes(params)
  end

  def status
    s = :active
    s = :paused unless paused_plan_id.nil?
    s = :expired if !expires_at.nil? && expires_at < Time.zone.today
    s = :cancel_pending unless cancelled_at.nil?
    s = :cancelled unless active
    s
  end

  def admin_all_users
    user_permissions.each do |up|
      up.account_admin = true
      up.save
    end
  end
end
