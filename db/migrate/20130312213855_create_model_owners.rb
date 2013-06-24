class CreateModelOwners < ActiveRecord::Migration
  def change
    create_table :model_owners do |t|
      t.integer :model_id
      t.string :model_name
      t.string :model_owner_name
      t.string :model_owner_id
      t.timestamps
    end
  end
end
