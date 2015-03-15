class LatexTemplate < ActiveRecord::Base
  has_icon "file-text-o"
  validates :model, uniqueness: true
	is_versioned
end
