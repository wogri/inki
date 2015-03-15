class CreateInkiTestGroups < ActiveRecord::Migration
  def change
    create_table :inki_test_groups do |t|
      t.string :name
      t.text :comment
      t.timestamps null: false
    end
  end
end
