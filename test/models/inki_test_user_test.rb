require 'test_helper'

class InkiTestUserTest < ActiveSupport::TestCase
  test "validations work" do
    assert_not InkiTestUser.new.save
  end

  test "dispatches are created" do
    user = InkiTestUser.new
    user.name = "my test user"
    user.mailaddress = "my@test.user.com"
    user.active = true
    assert user.save
    user.dispatch(operation: "create")
    dispatch_job = DispatchJob.where(inki_model_name: "inki_test_users", model_id: user.id, model_operation: "create").first
    assert dispatch_job
    user.mailaddress = "my_other@test.user.com"
    assert user.save
    # InkiTestUser.should_receive(:dispatch)
    user.dispatch(operation: "update")
    dispatch_job = DispatchJob.where(inki_model_name: "inki_test_users", model_id: user.id, model_operation: "update").first
    assert dispatch_job
    assert user.destroy
    # InkiTestUser.should_receive(:dispatch)
    user.dispatch(operation: "destroy")
    dispatch_job = DispatchJob.where(inki_model_name: "inki_test_users", model_id: user.id, model_operation: "destroy").first
    assert dispatch_job
  end
   

end
