# wogri@wogri.com - a monkey-patch for the generalized models
class ActiveRecord::Base

	# attr_accessible :_color
	attr_protected

	after_destroy do |model|
		model._operation = :destroy
	end

	after_update do |model|
		model._operation = :update
	end

	after_create do |model|
		model._operation = :create
	end

	after_commit :dispatch

	def _operation=(value)
		@operation = value
	end

	def _operation
		@operation
	end

	def _dispatch_id=(value)
		@dispatch_id = value
	end

	def _dispatch_id
		@dispatch_id
	end

	# creates or updates ownership for a model.
	# if owner doesn't exist, it will be created.
	def update_owner(owner_id, owner_name)
		owner = ModelOwner.where(:model_name => self.class.table_name, :model_id => self.id).first
		if owner and owner.model_owner_id == owner_id 
			return
		elsif owner # owner exists, but the owner just changed
			owner.model_owner_name = owner_name
			owner.model_owner_id = owner_id
			owner.save
		else # owner does not exist, create it
			ModelOwner.create(:model_name => self.class.table_name, :model_id => self.id, :model_owner_name => owner_name, :model_owner_id => owner_id)
		end
	end

	# when an object is destroyed, also it's owner should be destroyed. 
	# nothing is destroyed if no owner exists
	def destroy_owner!
		owner = ModelOwner.where(:model_name => self.class.table_name, :model_id => self.id).first
		owner.delete if owner
	end

	# returns name of owner by searching the database for it
	def _owner_name
		owner = ModelOwner.where(:model_name => self.class.table_name, :model_id => self.id).first
		owner.model_owner_name if owner
	end

	def self.default_order
		if @_default_order_attribute
			[@_default_order_attribute.to_s, @_default_order_direction]
		else
			[self.sorted_attributes.first.to_s, "ASC"]
		end
	end

	def self.sort_by(attribute, order = "ASC")
		@_default_order_attribute = attribute
		@_default_order_direction = order
	end

	def _owner_id
		owner = ModelOwner.where(:model_name => self.class.table_name, :model_id => self.id).first
		owner.model_owner_id if owner
	end

	# returns the fields that are shown in the list-view of a table. 
	# this is either by the +index_order+ directive in the model or by just going through all the column_names of the model.
	def self.index_fields
		if defined? @_index_fields
			@_index_fields
		else
			#column_names = self.column_names.map do |m|
				#m.to_sym
			#end
			sorted_attributes
		# 	sorted_attrs + (column_names - sorted_attrs - ["created_at", "updated_at", "id"])
		end
	end 

	def self.edit_partials 
		if defined? @edit_partials 
			@edit_partials
		else
			[]
		end
	end 

	def self.show_partials 
		if defined? @show_partials
			@show_partials
		else
			[]
		end
	end 

	def self.visible_relations 
		if defined? @visible_relations 
			@visible_relations
		else
			self.reflections.keys - [:versions]
		end
	end 

	def self.hidden_fields 
		if defined? @hidden_fields
			@hidden_fields
		else
			[]
		end
	end 

	def self.belongs_to_hidden_fields
		relations = visible_relations - hidden_fields - sorted_attributes
		fields = []
		object = self.new
		relations.each do |r|
			if object.reflections[r].macro == :belongs_to
				fields << r
			end
		end
		fields
	end

#	def self.search_fields(*values)
#		@_search_fields = []
#		values.collect do |v|
#			@_search_fields.push(v)
#		end
#	end

	def self.read_only(*values)
		@_read_only_fields= []
		values.collect do |v|
			@_read_only_fields.push(v)
		end
	end

	def self.attribute_order(*values)
		@_sorted_attributes = []
		values.collect do |v|
			@_sorted_attributes.push(v)
		end
		acts_as_indexed :fields => self.sorted_attributes + [ :__belongs_to__ ]
	end

	def self.special_buttons(hash)
		@_special_buttons = hash
	end
	
	def self.attribute_properties(hash)
		@_attribute_description = hash
	end

	def self.has_special_controller_buttons?
		if defined? @_special_buttons
			hash = {}
			@_special_buttons.each do |key, value|
				if value[:controller_option]
					hash[key] = value
				end
			end
			hash
		else
			{}
		end
	end

	def self.has_special_buttons?
		if defined? @_special_buttons
			@_special_buttons
		else
			{}
		end
	end

	def self.index_order(*values)
		@_index_fields = []
		values.collect do |v|
			@_index_fields.push(v)
		end
	end

	#def self.order_test
		#if defined? @_sorted_attributes
			#@_sorted_attributes
		#end
	#end

	# a method that returns true if acts_as_indexed is enabled.
	def self.searching_enabled?
		self.methods.member?(:with_query)
	end

	# returns true if the given attribute is a belongs_to relationship
	def self.belongs_to?(attribute)
		self.reflections[attribute.to_sym] and self.reflections[attribute.to_sym].macro == :belongs_to
	end

	# this attribute is used when a belongs_to relationship wants to display relevant data from the model it belongs to. 
	# by default it will show the first attribute the model is sorted by. 
	def self.reference_attribute
		sorted_attributes.first
	end

	# this returns the reference attribute (as it can be called by class above)
	def reference_attribute
		content = self.send(self.class.reference_attribute)
		if extra = self.class.get_belongs_to_extra_info
			content = "#{content} #{extra.call(self)}"
		end
		content
	end

	# this is used in addition to the reference attribute in belongs-to relationships
	def self.belongs_to_extra_info(code)
		@belongs_to_extra_info = code
	end

	def self.get_belongs_to_extra_info
		@belongs_to_extra_info
	end

	def self.sorted_attributes
		if defined? @_sorted_attributes
			@_sorted_attributes
		else
			(self.attribute_names - ["created_at", "updated_at", "id"]).sort.collect do |a|
				a.to_sym
			end
		end
	end 

	def self.attribute_description
		if defined? @_attribute_description
			@_attribute_description
		else
			{}
		end
	end 

	# saves lambda. 
	def self.show_if(code)
		@show_if = code
	end

	# calls the lambda from show_if
	def self.show_relation?(object)
		if not @show_if
			true
		else
			begin
				@show_if.call(object)
			rescue StandardError => e
				logger.error("show_relation? monkey patch function crashed. this might be okay if the lambda-function doesn't check intensively on classes or such. error was: ")
				logger.error(e.backtrace.join("\n"))
				false
			end
		end
	end

	def self.title(attribute)
		@_title_field = attribute
	end

	def self.title_field
		if defined? @_title_field
			@_title_field
		end
	end

	def title
		if self.class.title_field
			self.send(self.class.title_field)
		elsif defined? self.class.index_fields
			self.send(self.class.index_fields.first)
		else
			nil
		end
	end

	# overrides the table-width in index-view (to make specific columns wider)
	def self.column_style(field)
		if defined? @column_style
			@column_style[field.to_sym]
		end
	end

	def self.help(*values)
		@help_array = []
		values.collect do |v|
			@help_array.push(v)
		end
	end

	def self.help_text(field)
		if defined? @help_array and help_text = @help_array.member?(field.to_sym)
			"help_#{field}".to_sym
		end
	end
	
	def self.read_only?(field, new = false)
		if defined? @_read_only_fields and not new
			@_read_only_fields.member?(field.to_sym)
		end
	end

	def self.colored?
		if defined? @colored
			true
		end
	end

	def self.can_be_colored
		@colored = true
	end

	def self.can_be_dispatched
		@dispatchable = true
	end

	def self.dispatchable?
		@dispatchable
	end

	# create a dispatch-job according to the called C(R)UD Function
	def dispatch
		if not self.class.dispatchable? or not self._operation
			logger.info("#{self.class}/#{self._operation} not dispatchable, will not dispatch anything.")
			return
		end
		logger.info("######### DISPATCHING: #{self.class}/#{self._operation}")
		dispatch_hash = {
			:model_name => self.class.table_name,
			:model_id => self.id,
			:model_operation => self._operation.to_s,
			:retry_at => Time.now,
			:done => false,
			:locked => false
		}
		dispatch = DispatchJob.new(dispatch_hash)
		# there's nothing to do if there is already a dispatch-job in the queue that matches our dispatch-job.
		if self._operation == :destroy # if a model is destroyed, we need to save the model data for later
			dispatch.model_description = self.to_yaml
		end
		search_filter = dispatch_hash.clone
		search_filter.delete(:retry_at)
		if DispatchJob.where(search_filter).first
			logger.warn("Not inserting Dispatch-Job for #{dispatch_hash.inspect}, as this dispatch job already exists in the database.")
			return
		else
			dispatch.save
			logger.info("owner id: #{self._owner_id}")
			dispatch.update_owner(self._owner_id, self._owner_name)
		end

	end

	# this function returns values of belongs-to relationships
	def __belongs_to__
		return_string = []
		self.class.reflect_on_all_associations.each do |association| 
			if association.macro == :belongs_to
				model = self.send(association.name)
				if model
					return_string.push model.reference_attribute 
				end
			end
		end
		return_string.join " "
	end

	# returns the current color code, if any 
	def _color
		color = Color.where(:model_name => self.class.to_s, :model_id => self.id).first
		if color
			color.rgb_id
		end
	end

	# sets the color code
	def _color=(value)
		return if not value
		color = Color.where(:model_name => self.class.to_s, :model_id => self.id).first
		if color
			color.update_attribute(:rgb_id, value)
		else
			Color.create(:model_name => self.class.to_s, :model_id => self.id, :rgb_id => value)
		end
	end

	# removes all charactes with a charset > 128
	def to_ascii(string)
		string.unpack("U*").map do |c| 
			c.chr if c < 128
		end.join
	end

	# generate csv from my data
	def self.to_csv(objects = all)
		require 'csv'
  	CSV.generate do |csv|
      csv << sorted_attributes
      objects.each do |item|
				logger.info(item.inspect)
				csv << sorted_attributes.map do |attr|
					if belongs_to?(attr)
        		reference_element = item.send(attr)
						if reference_element
							reference_element.reference_attribute
						else
							nil
						end
					else
        		item.send(attr)
					end
				end
      end
    end
	end

end
