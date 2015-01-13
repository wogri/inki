class Usergroup < ActiveRecord::Base

  index_order :name, :comment
	attribute_order :name, :comment
	@column_style = {
		:comment => :nowrap # don't wrap blanks empty 
	}

	has_icon "group"
  paginates_per 10

  has_many :users, :dependent => :delete_all


	validates :name, :comment, :presence => true
  validates :name, :uniqueness => true

end
