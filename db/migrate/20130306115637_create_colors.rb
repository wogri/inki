class CreateColors < ActiveRecord::Migration[4.2]
  def change
    create_table :colors do |t|
      t.integer :rgb_id
      t.string :model_name
      t.integer :model_id
      t.timestamps
    end
  end
end
