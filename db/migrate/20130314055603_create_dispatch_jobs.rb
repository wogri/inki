class CreateDispatchJobs < ActiveRecord::Migration[4.2]
  def change
    create_table :dispatch_jobs do |t|
      t.string :model_name
      t.integer :model_id
      t.string :model_operation
      t.integer :retries
      t.boolean :locked
      t.datetime :locked_at
      t.boolean :done
      t.text :model_description
			t.datetime :retry_at
			t.integer :lock_version
			t.integer :current_todos

      t.timestamps
    end
  end
end
