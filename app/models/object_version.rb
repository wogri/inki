class ObjectVersion < ActiveRecord::Base

	sort_by :created_at, "DESC"

	# creates an object from a versioned entry
	def to_inki_object
		YAML.load(self.serialized_object)
		#object = Object.const_get(self.model_name).new
		# instead of doing direct deserialisation, do it per key value - higher success rates if the database schema changes
		#yaml.each do |key, value|
		#	begin
		#	object.send("key=", value)
		#	rescue StandardError => e
		#		logger.error("assignment error on version restore: #{e.join('\n')}")
		#	end
		#end
		#object
	end

	# restore this object to the original object
	def restore!

	end

end
