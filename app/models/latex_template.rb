class LatexTemplate < ActiveRecord::Base
  # serves as a template storage for latex templates that contain ERB. Can be converted to PDF.
  has_icon "file-text-o"
  validates :model, uniqueness: true
	is_versioned
end
