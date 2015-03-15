class InkiTestUserRight < ActiveRecord::Base
  belongs_to :inki_test_user
  belongs_to :inki_test_right
  attribute_order :inki_test_right
end
