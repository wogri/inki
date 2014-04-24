require 'active_support/concern'

module Inki
  extend ActiveSupport::Concern

	def _operation=(value)
		@operation = value
	end

	def _operation
		@operation
	end

	def _dispatch_model_description=(value)
		@_dispatch_model_description = value
	end

	def _dispatch_model_description
		@_dispatch_model_description
	end

	def _dispatch_id=(value)
		@dispatch_id = value
	end

	def _dispatch_id
		@dispatch_id
	end

	def _serialized=(value)
		@_serialized = value
	end

	def _serialized
		@_serialized
	end

	def new_record!
		@new_record = true
	end

	# creates or updates ownership for a model.
	# if owner doesn't exist, it will be created.
	def update_owner(owner_id, owner_name)
		if not ActiveRecord::Base.connection.table_exists? 'model_owners'
			return
		end
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
		if not ActiveRecord::Base.connection.table_exists? 'model_owners'
			return
		end
		owner = ModelOwner.where(:model_name => self.class.table_name, :model_id => self.id).first
		owner.delete if owner
	end

	# returns name of owner by searching the database for it
	def _owner_name
		if not ActiveRecord::Base.connection.table_exists? 'model_owners'
			return ''
		end
		owner = ModelOwner.where(:model_name => self.class.table_name, :model_id => self.id).first
		owner.model_owner_name if owner
	end

	def _owner_id
		if not ActiveRecord::Base.connection.table_exists? 'model_owners'
			return nil
		end
		owner = ModelOwner.where(:model_name => self.class.table_name, :model_id => self.id).first
		owner.model_owner_id if owner
	end

	# this returns the reference attribute (as it can be called by class above)
	def reference_attribute
		content = self.send(self.class.reference_attribute)
		if extra = self.class.get_belongs_to_extra_info
			content = "#{content} #{extra.call(self)}"
		end
		content
	end

	def cipher(key, iv = nil, data, options) 
		require 'openssl'
		require 'digest'
		aes = OpenSSL::Cipher.new('AES-256-CBC')
		if options[:method] == :encrypt
			aes.encrypt
			iv = aes.random_iv
		elsif options[:method] == :decrypt
			aes.decrypt
			aes.iv = iv
		end
		aes.key = Digest::SHA256.digest(key + options[:shared_cipher].to_s) 
		{:cipher => aes.update(data) + aes.final, :iv => iv}
	end

	# this method just boldly invokes encryption, it will find out which attributes need to be encrypted and then call encrypt_attribute
	def encrypt!(password, inki_cipher)
		if attributes = self.class.is_encrypted?
			attributes.each do |attribute|
				self.send("#{attribute}=", encrypt_attribute(attribute, password, inki_cipher))
			end
			self.save
		end
	end

	def decrypt(password, inki_cipher)
		if attributes = self.class.is_encrypted?
			attributes.each do |attribute|
				self.send("#{attribute}=", decrypt_attribute(attribute, password, inki_cipher))
			end
		end
	end

	def encrypt_attribute(attribute, key, shared_cipher = '')
		aes = cipher(key, nil, self.send(attribute), method: :encrypt, shared_cipher: shared_cipher)
		Base64.encode64(aes[:cipher]) + ';' + Base64.encode64(aes[:iv])
	end

	def decrypt_attribute(attribute, key, shared_cipher = '')
		cipher, iv = self.send(attribute).split(/;/)
		aes = cipher(key, Base64.decode64(iv), Base64.decode64(cipher), method: :decrypt, shared_cipher: shared_cipher)
		aes[:cipher]
	end

	def as_json(options = {})
		attrs = self.class.hidden_json_attributes
		options[:except] ||= attrs if attrs
		super(options)
	end

	# returns the type of relationship of this property - can either be: has_many, belongs_to, has_and_belongs_to_many, has_one or has_many_through
	def rails_relation(attribute)
		reflection = self.reflections[attribute.to_sym]
		if reflection.class == ActiveRecord::Reflection::ThroughReflection
			return :has_many_through
		elsif reflection.class == ActiveRecord::Reflection::AssociationReflection
			return reflection.macro
		end
	end

	def model_title
		if self.class._title_field
			self.send(self.class._title_field)
		elsif defined? self.class.index_fields
			self.send(self.class.index_fields.first)
		else
			nil
		end
	end

	# create a dispatch-job according to the called C(R)UD Function
	def dispatch(options = nil) # we can overwrite the operation if we want to
		if options.class == String
			self._operation = options
		elsif options.class == Hash
			self._operation = options[:operation] if options[:operation]
		end
		if not self.class.dispatchable? or not self._operation
			logger.info("#{self.class}/#{self._operation} not dispatchable, will not dispatch anything.")
			return
		end
		logger.info("######### DISPATCHING: #{self.class}/#{self._operation}")
		dispatch_hash = {
			:model_name => self.class.table_name,
			:model_id => self.id,
			:model_operation => self._operation.to_s,
			:model_description => self._dispatch_model_description,
			:retry_at => Time.now,
			:done => false,
			:locked => false, 
			:owner_mail_address => self._owner_id
		}
		if options.class == Hash and options[:retry_at]
			dispatch_hash[:retry_at] = options[:retry_at]	
		end
		# add 'yourself' to the dispatch-process, just to be sure
		if not self._dispatch_model_description 
			dispatch_hash[:model_description] = self.to_yaml
		end
		dispatch = DispatchJob.new(dispatch_hash)
		search_filter = dispatch_hash.clone
		search_filter.delete(:retry_at)
		# there's nothing to do if there is already a dispatch-job in the queue that matches our dispatch-job.
		if DispatchJob.where(search_filter).first
			logger.warn("Not inserting Dispatch-Job for #{dispatch_hash.inspect}, as this dispatch job already exists in the database.")
			return
		else
			dispatch.save
			logger.info("owner id: #{self._owner_id}")
			dispatch.update_owner(self._owner_id, self._owner_name)
		end
		# find out if this object has been deleted and if there is either a has_and_belongs_to_many or has_many_through association. 
		# why? because the object on the "other side" has to be notified about the change (:update) - rails hasn't consistelnty im-
		# plemented that: http://guides.rubyonrails.org/association_basics.html#the-has-and-belongs-to-many-association
		if @notify_after_dispatch
			@notify_after_dispatch.each do |association|
				self.send(association).each do |other_object|
					other_object.dispatch(:update)
				end
			end
		end
	end

	# save the previous version of the object
	def create_version
		return if not _serialized
		if not defined?(ObjectVersion)
			logger.error("object_version.rb Class doesn't exist in /app/models.")
			return 
		end
		if not ActiveRecord::Base.connection.table_exists? 'object_versions'
			logger.error("object_versions table doesn't exist. Run rake db:migrate RAILS_ENV=#{Rails.env}")
			return
		end
		ObjectVersion.create(
			:format => 1, 
			:model_owner_id => self._owner_id,
			:model_id => self.id,
			:model_name => self.class.to_s,
			:serialized_object => _serialized
		)
	end

	# returns an active record relation with all the model versions in it (ObjectVersion instances)
	def versions
		ObjectVersion.where(
			:format => 1,
			:model_id => self.id, 
			:model_name => self.class.to_s, 
		).order("created_at DESC")
	end

	# returns the previous version of this element - can only be used with "real" elements, no pseudo elements like ObjectVersion deserialized objects will work with this.
	def previous_version
		if not self.class.is_versioned?
			raise "object is not versioned, configure versioning in model file"
		end
		if previous_object_version = self.versions.first
			previous_object_version.to_inki_object
		else
			nil
		end
	end

	# this function returns values of belongs-to relationships
	def __belongs_to__
		return_string = []
		self.class.reflect_on_all_associations(:belongs_to).each do |association| 
			model = self.send(association.name)
			if model
				return_string.push model.reference_attribute 
			end
		end
		return_string.join " "
	end

	# dummy, you can not actually get an inki-password.
	def _inki_password
		@_inki_password
	end

	# dummy, you can not actually store an inki-password.
	def _inki_password=(value)
		@_inki_password = value
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

# Start Class Methods
  module ClassMethods
		# generate csv from my data
		def to_csv(objects = all)
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

		def default_order
			if @_default_order_attribute
				[@_default_order_attribute.to_s, @_default_order_direction]
			else
				[self.sorted_attributes.first.to_s, "ASC"]
			end
		end

		# sets an icon
		def has_icon(icon)
			@inki_icon = icon.to_sym
		end

		# returns the icon symbol
		def inki_icon
			@inki_icon
		end

		def sort_by(attribute, order = "ASC")
			@_default_order_attribute = attribute
			@_default_order_direction = order
		end

		# returns the fields that are shown in the list-view of a table. 
		# this is either by the +index_order+ directive in the model or by just going through all the column_names of the model.
		def index_fields
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

		def edit_partials 
			if defined? @edit_partials 
				@edit_partials
			else
				[]
			end
		end 

		def show_partials 
			if defined? @show_partials
				@show_partials
			else
				[]
			end
		end 

		# returns the (user-) visible relationships between elements
		def visible_relations 
			if defined? @visible_relations 
				@visible_relations
			else
				association_helper_models = []
				# find 
				self.reflections.keys.each do |key|
					if self.reflections[key].class == ActiveRecord::Reflection::ThroughReflection
						association_helper_models.push self.reflections[key].options[:through]
					end
				end
				self.reflections.keys - association_helper_models
			end
		end 

		def hidden_fields 
			if defined? @hidden_fields
				@hidden_fields
			else
				[]
			end
		end 

		def belongs_to_hidden_fields
			relations = visible_relations - hidden_fields - sorted_attributes
			fields = []
			object = self.new
			relations.each do |r|
				if object.reflections[r].macro == :belongs_to
					fields << object.reflections[r].foreign_key.to_sym
				end
			end
			fields
		end

#	def search_fields(*values)
#		@_search_fields = []
#		values.collect do |v|
#			@_search_fields.push(v)
#		end
#	end

		def read_only(*values)
			@_read_only_fields= []
			values.collect do |v|
				@_read_only_fields.push(v)
			end
		end

		def encrypt(*values)
			@_encrypted_attributes = []
			# require the inki password field to be filled in (only if _inki_password receives at least the empty string, meaning that if it is not shown, it won't be validated. 
			validates :_inki_password, presence: true, :length => { :minimum => 5, :maximum => 40 }, :confirmation => true, :if => lambda { self._inki_password }
			validates :_inki_password_confirmation, :presence => true, :if => lambda { self._inki_password }
			values.collect do |v|
				@_encrypted_attributes.push(v.to_sym)
			end
		end

		def is_encrypted?(attribute = nil)
			if defined? @_encrypted_attributes 
				if not attribute
					@_encrypted_attributes 
				elsif attribute
					@_encrypted_attributes.member?(attribute.to_sym)
				end
			end
		end

		def attribute_order(*values)
			@_sorted_attributes = []
			values.collect do |v|
				@_sorted_attributes.push(v)
			end
			if not @_does_not_act_as_indexed
				acts_as_indexed :fields => self.sorted_attributes + [ :__belongs_to__ ]
			end
		end
	
		def does_not_act_as_indexed
			@_does_not_act_as_indexed = true
		end

		def special_buttons(hash)
			if @_special_butttons
				@_special_buttons.merge!(hash)
			else
				@_special_buttons = hash
			end
		end
		
		def attribute_properties(hash)
			@_attribute_description = hash
		end

		def has_special_controller_buttons?
			hash = {}
			if defined? @_special_buttons
				@_special_buttons.each do |key, value|
					if value[:controller_option]
						hash[key] = value
					end
				end
				hash
			end
			# go through the attribute properties, and find :graph values. for these behave as if special buttons had been set. yay.
			attribute_description.each do |key, value|
				if value == :graph
					hash[key] = {
						:description => :show_graph, 
						:icon => "icon-bar-chart", 
						:controller_option => true, 
						:graph => true # this tells the controller to treat this one special
					}
				end
			end
			hash
		end

		# sets up special buttons hash in a way that graphs can be created from datasets without writing controller or view code
		def graph_for(attribute, options = {})
			hash = {}
			hash[attribute] = {
				:description => :show_graph, 
				:icon => "icon-bar-chart", 
				:controller_option => true, 
				:graph => true, # this tells the controller to treat this one special
				:graph_options => options
			}
			if @_special_buttons
				@_special_buttons.merge! hash
			else
				@_special_buttons = hash
			end
		end

		def has_special_buttons?
			if defined? @_special_buttons
				@_special_buttons
			else
				{}
			end
		end
	
		# returns the property hash for a special button
		def special_button(option)
			if defined? @_special_buttons and return_value = @_special_buttons[option.to_sym]
				return_value
			end
		end

		def index_order(*values)
			@_index_fields = []
			values.collect do |v|
				@_index_fields.push(v)
			end
		end

		# this is the extension of a model in order to hide attributes during the creation of a database entry
		def hide_on_create(*values)
			@_inki_hide_on_create = []
			values.collect do |v|
				@_inki_hide_on_create.push(v.to_sym)
			end
		end

		def hidden_on_create?(attribute)
			return nil if not defined? @_inki_hide_on_create
			@_inki_hide_on_create.member?(attribute.to_sym)
		end

		#def order_test
			#if defined? @_sorted_attributes
				#@_sorted_attributes
			#end
		#end

		# a method that returns true if acts_as_indexed is enabled.
		def searching_enabled?
			self.methods.member?(:with_query)
		end

		# returns true if the given attribute is a belongs_to relationship
		def belongs_to?(attribute)
			self.reflections[attribute.to_sym] and self.reflections[attribute.to_sym].macro == :belongs_to
		end

		# this attribute is used when a belongs_to relationship wants to display relevant data from the model it belongs to. 
		# by default it will show the first attribute the model is sorted by. 
		def reference_attribute
			sorted_attributes.first
		end

		# this is used in addition to the reference attribute in belongs-to relationships
		def belongs_to_extra_info(code)
			@belongs_to_extra_info = code
		end

		def get_belongs_to_extra_info
			@belongs_to_extra_info
		end

		# strong parameters - we just return every parameter for now. 
		def strong_parameters
			attrs = self.attribute_names - ["created_at", "updated_at", "id"]
			attrs.push(:_color) if colored? # add the color attribute to the permitted attributes if the object is colorable
			if is_encrypted? # add the color attribute to the permitted attributes if the object is colorable
				attrs.push(:_inki_password) 
				attrs.push(:_inki_password_confirmation) 
			end
			attrs.collect do |a|
				a.to_sym
			end
		end

		def sorted_attributes
			if defined? @_sorted_attributes
				@_sorted_attributes
			else
				(self.attribute_names - ["created_at", "updated_at", "id"]).sort.collect do |a|
					a.to_sym
				end
			end
		end 

		def attribute_description
			if defined? @_attribute_description
				@_attribute_description
			else
				{}
			end
		end 

		# saves lambda. 
		def show_if(code)
			@show_if = code
		end

		# calls the lambda from show_if
		def show_relation?(object)
			if not @show_if
				true
			else
				begin
					@show_if.call(object)
				rescue StandardError => e
					logger.error("show_relation? monkey patch function crashed. this might be okay if the lambda-function doesn't check intensively on classes or such. error was: #{e}")
					logger.error(e.backtrace.join("\n"))
					false
				end
			end
		end

		def model_title(attribute)
			@_title_field = attribute
		end

		def _title_field
			if defined? @_title_field
				@_title_field
			end
		end

		# overrides the table-width in index-view (to make specific columns wider)
		def column_style(field)
			if defined? @column_style
				@column_style[field.to_sym]
			end
		end

		def help(*values)
			@help_array = []
			values.collect do |v|
				@help_array.push(v)
			end
		end

		# returns the (already translated) help text for an object
		def help_text(field)
			translation = self.human_attribute_name("help_#{field}", :default => 0)
			if translation != 0
				translation
			else
				nil
			end
		end
		
		def read_only?(field, new = false)
			if defined? @_read_only_fields and not new
				@_read_only_fields.member?(field.to_sym)
			end
		end

		def colored?
			if defined? @_colored
				true
			end
		end

		def can_be_colored
			@_colored = true
		end
		
		# this enables a object lifecycle to be stored in the object_versions table
		def is_versioned
			@is_versioned = true
			before_destroy do |model|
				model._serialized = model.to_yaml
			end

			before_update do |model|
				# save the model as it was BEFORE it was updated
				model._serialized = self.class.find(model.id).to_yaml
			end

			after_commit :create_version
		end

		def is_expirable
			@is_expirable = true
		end

		def is_expirable?
			@is_expirable 
		end

		def hidden_json_attributes
			if defined? @hide_json_attributes and @hide_json_attributes.size > 0
				@hide_json_attributes
			else
				nil
			end
		end

		# overwrites the as_json method to remove specific json attributes (like passwords or other sensitive information)
		def hide_json_attributes(*attributes)
			@hide_json_attributes = []
			attributes.collect do |a|
				@hide_json_attributes.push(a.to_sym)
			end
		end

		# returns true if the class is versioned
		def is_versioned?
			@is_versioned 
		end

		# returns the latest object in the history of the object (e. g. the latest element when the element was deleted), nil if there is no such object. 
		def latest_inki_object_in_history(id)
      object = ObjectVersion.where(
        :format => 1,
        :model_id => id, 
        :model_name => self.to_s
      ).order("created_at DESC").first
      if not object
        return nil 
      else
        object.to_inki_object
			end
		end

		# this enables a model to be dispatchable. different callbacks will be registered right here
		def can_be_dispatched
			after_destroy do |model|
				model._operation = :destroy
			end

			after_update do |model|
				model._operation = :update
			end

			after_create do |model|
				model._operation = :create
				model._dispatch_model_description = model.to_yaml
			end

			before_destroy do |model|
				model._dispatch_model_description = model.to_yaml
				# find associations. associations need to be notified if they're m:n (after the commit)
				@notify_after_dispatch = []
				model.class.reflect_on_all_associations(:has_many).each do |association|
					@notify_after_dispatch.push association.name if association.class == ActiveRecord::Reflection::ThroughReflection
				end
				model.class.reflect_on_all_associations(:has_and_belongs_to_many).each do |association|
					@notify_after_dispatch.push association.name 
				end
			end

			before_update do |model|
				model._dispatch_model_description = model.to_yaml
			end

			after_commit :dispatch
			@dispatchable = true
		end

		def dispatchable?
			@dispatchable
		end
	end

end
ActiveRecord::Base.send(:include, Inki)
