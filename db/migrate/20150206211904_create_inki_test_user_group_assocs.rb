class CreateInkiTestUserGroupAssocs < ActiveRecord::Migration
  def change
    create_table :inki_test_user_group_assocs do |t|
      t.integer :inki_test_group_id
      t.integer :inki_test_user_id
      t.timestamps null: false
    end
  end
end
