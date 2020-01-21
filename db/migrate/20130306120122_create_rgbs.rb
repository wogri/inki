class CreateRgbs < ActiveRecord::Migration[4.2]
  def change
    create_table :rgbs do |t|
      t.string :rgb
      t.string :name

      t.timestamps
    end
  end
end
