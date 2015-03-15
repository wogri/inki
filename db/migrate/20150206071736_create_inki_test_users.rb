class CreateInkiTestUsers < ActiveRecord::Migration
  def change
    create_table :inki_test_users do |t|
      t.string :name
      t.string :username 
			t.text :comment
      t.string :mailaddress
      t.string :password 
      t.boolean :active
      t.timestamps null: false
    end
  end
end
