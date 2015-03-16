class LatexTemplate < ActiveRecord::Base
  # serves as a template storage for latex templates that contain ERB. Can be converted to PDF.
  has_icon "file-text-o"
  validates :model, uniqueness: true
	attribute_properties :template => :truncate
	is_versioned
end
