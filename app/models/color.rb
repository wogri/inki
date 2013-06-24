class Color < ActiveRecord::Base

	attribute_order :model_id, :model_name, :rgb
	belongs_to :rgb
end
