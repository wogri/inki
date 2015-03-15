class CreateInkiTestRights < ActiveRecord::Migration
  def change
    create_table :inki_test_rights do |t|
      t.string :inki_right
      t.timestamps null: false
    end
  end
end
