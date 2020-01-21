class AddOwnerMailAddressToDispatchJob < ActiveRecord::Migration[4.2]
  def change
    add_column :dispatch_jobs, :owner_mail_address, :string
  end
end
