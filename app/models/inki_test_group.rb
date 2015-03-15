class InkiTestGroup < ActiveRecord::Base
	has_many :inki_test_users, :through => :inki_test_user_group_assocs
  has_many :inki_test_user_group_assocs
end
