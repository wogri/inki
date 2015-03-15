class InkiTestUserGroupAssoc < ActiveRecord::Base
  belongs_to :inki_test_user
  belongs_to :inki_test_group
end
