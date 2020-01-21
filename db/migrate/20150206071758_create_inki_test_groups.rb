class CreateInkiTestGroups < ActiveRecord::Migration[4.2]
  def change
    create_table :inki_test_groups do |t|
      t.string :name
      t.text :comment
      t.timestamps null: false
    end
  end
end
