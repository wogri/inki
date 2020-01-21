class CreateObjectVersions < ActiveRecord::Migration[4.2]
  def change
    create_table :object_versions do |t|
      t.integer :model_id
      t.string :model_name
			t.integer :format
			t.text :serialized_object
			t.string :model_owner_id
      t.timestamps
    end
  end
end
