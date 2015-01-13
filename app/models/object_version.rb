class ObjectVersion < ActiveRecord::Base

	sort_by :created_at, "DESC"

	# creates an object from a versioned entry
	def to_inki_object
		YAML.load(self.serialized_object)
	end

	# restore this object to the original object
	def restore!

	end

end
