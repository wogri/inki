class CreateLatexTemplates < ActiveRecord::Migration
  def change
    create_table :latex_templates do |t|
      t.string :model
      t.text :template

      t.timestamps null: false
    end
  end
end
