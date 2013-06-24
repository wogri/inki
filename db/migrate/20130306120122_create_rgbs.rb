class CreateRgbs < ActiveRecord::Migration
  def change
    create_table :rgbs do |t|
      t.string :rgb
      t.string :name

      t.timestamps
    end
  end
end
