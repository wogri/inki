class InkiTestUser < ActiveRecord::Base
	has_many :inki_test_groups, :through => :inki_test_user_group_assocs
  has_many :inki_test_user_group_assocs
  has_many :inki_test_user_rights
  validates :name, presence: true
  attribute_order :name, :username, :comment, :mailaddress, :password, :active
  can_be_dispatched
end
