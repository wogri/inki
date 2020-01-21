class CreateInkiTestUserRights < ActiveRecord::Migration[4.2]
  def change
    create_table :inki_test_user_rights do |t|
      t.integer :inki_test_user_id
      t.integer :inki_test_right_id
      t.timestamps null: false
    end
  end
end
