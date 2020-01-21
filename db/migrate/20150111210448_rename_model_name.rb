class RenameModelName < ActiveRecord::Migration[4.2]
  def change
    rename_column :object_versions, :model_name, :inki_model_name
    rename_column :model_owners, :model_name, :inki_model_name
    rename_column :dispatch_jobs, :model_name, :inki_model_name
    rename_column :colors, :model_name, :inki_model_name
  end
end
