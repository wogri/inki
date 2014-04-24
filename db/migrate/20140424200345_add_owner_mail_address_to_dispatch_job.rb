class AddOwnerMailAddressToDispatchJob < ActiveRecord::Migration
  def change
    add_column :dispatch_jobs, :owner_mail_address, :string
  end
end
