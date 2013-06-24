class Rgb < ActiveRecord::Base

	has_many :colors, :dependent => :delete_all
end
