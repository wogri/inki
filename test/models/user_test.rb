require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test "validations work" do
    user = User.new
    assert_not user.save
  end
end
