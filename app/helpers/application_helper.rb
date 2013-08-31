# -*- encoding : utf-8 -*-
module ApplicationHelper

	# returns an font-awesome icon
	def icon(name)
		content_tag(:i, nil, :class => name)  + " "
	end

	# returns the active main menu name to generate a wonderful highlight in the menu
	def active_menu(menu)
		c = controller_name
		if menu.class == Array
			menu.each do |m|
				if active_menu(m)
					if m.class == Hash
						#logger.info("returning #{m.keys.first} in interation #{iteration}")
						return m.keys.first
					else
						return true
					end
				end
			end
			return nil
		end
		if menu.class == Hash
			first_hash_element = menu[menu.keys.first]
		end
		if menu.class == String 
			if menu == c
				return true
			else
				return false
			end
		else
			return active_menu(first_hash_element) if first_hash_element
		end
	end

	# builds the whole bootstrap menu, including all hierachies
	def menu_link(element, iteration = 0, options = {})
		iteration += 1
		menu = []
		if element.class == Array # this is a list of elements. re-call menu-link again.
			element.each do |e|
				menu << menu_link(e, iteration, options)
			end
			return menu.join("\n").html_safe
		elsif element.class == Hash  # there is a sub-menu below this element
			html_class = ["dropdown"]	
			first_key = element.keys.first
			link_text = "#{t(first_key)} <b class=\"caret\"></b>".html_safe
			if iteration == 2 # first sub-element
				html_class << "active" if options[:active_menu] == first_key
				link = link_to(link_text, '/#', {:class => "dropdown-toggle", "data-toggle" => "dropdown"})
				submenu = link
				submenu << content_tag(:ul, menu_link(element[first_key], iteration, options), :class => "dropdown-menu")
				menu << content_tag(:li, submenu, :class => html_class.join(" "))
			else # deeper sub-elements need to be rendered differently
				html_class = ["dropdown-submenu"]
				link_text = t(first_key)
				link = link_to(link_text, menu_link(element[first_key].first, iteration, :just_the_link => true))
				submenu = link
				submenu << content_tag(:ul, menu_link(element[first_key], iteration, options), :class => "dropdown-menu")
				menu << content_tag(:li, submenu, :class => html_class.join(" "))
			end
		elsif element.class == String # just a normal menu with a fixed target
			link =  self.send("#{element}_path")
			if options[:just_the_link]
				return link
			end
			link = link_to(t(element), link, :class => "spinner")
			menu << content_tag(:li, link.html_safe)
		end
		menu.join("\n").html_safe
	end

	# generate a split button element
	def split_button(elements)
		html = ""
		html << elements.shift
		html << link_to(content_tag(:span, "", :class => "caret"), '#', :class => "btn dropdown-toggle btn-sm btn-default", "data-toggle" => "dropdown")
		sub_elements = ""
		elements.each do |element|
			sub_elements << content_tag(:li, element)
		end
		html << content_tag(:ul, sub_elements.html_safe, :class => "dropdown-menu", :role => "menu")
		content_tag(:div, html.html_safe, :class => "btn-group") 
	end

	# creates the typical edit, show and delete buttons
	def option_buttons(object, options = {})
		options.merge!({:action_name => controller.action_name}) unless options[:action_name]
		options.merge!({:non_dropdown_view => true}) if @non_dropdown_view
		object_name = object.class.to_s.underscore
		link_hash = {:ajax_id => @ajax_id}
		link_hash.merge!({
			:from_show_table => @from_show_table, 
			:show_id => @show_id || @show_object.id,
			:add_existing_model => @add_existing_model,
			:previous_ajax_id => @previous_ajax_id,
		}) if @from_show_table
		link_hash.merge!({:non_dropdown_view => true}) if options[:non_dropdown_view] or @non_dropdown_view
		html = []
		if @add_existing_model # these are options for a m-to-n relationship view
			l = link_hash.clone
			l.delete(:ajax_id)
			checkbox = form_for(object, :remote => true, :html => {:style => "display: inline;"}) do |f|  
				inner_html = []
				associated = object.send(@from_show_table).exists?(@show_object) # returns true if the show_object is already part of the association
				l.each do |k, v|
					inner_html << hidden_field_tag(k, v)
				end
				inner_html << check_box_tag("associated", true, associated, :onclick => "$(this).closest('form').submit();", :style => "margin-right: 5pt;")
				inner_html.join("\n").html_safe
			end
		end
		unless options[:non_dropdown_view] or @non_dropdown_view
			loupe = icon("icon-reorder")
			html << link_to(loupe + t(:show), self.send("#{object_name}_path", object, link_hash), :remote => true, :class => "btn btn-sm btn-default spinner")
			html << link_to(loupe + t(:show_no_remote), self.send("#{object_name}_path", object, link_hash), :class => "spinner") if not @add_existing_model
		end
		if @right == :write and not @add_existing_model # add_existing_model means a has_and_belongs_to_many realtionship selection view :) 
			edit_image = icon("icon-pencil")
			edit_text = (edit_image + t(:edit)).html_safe
			edit_path = self.send("edit_#{object_name}_path", object, link_hash)
			delete_image = icon("icon-trash")
			delete_text = (delete_image + t(:delete)).html_safe
			delete_path = self.send("#{object_name}_path", object, link_hash)
			if options[:non_dropdown_view]
				html << link_to(edit_text, edit_path, :class => "btn btn-default btn-sm spinner")
				html << link_to(delete_text, delete_path, :method => :delete, :class => "spinner", :data => { :confirm => t(:sure) + "?"})
			else
				html << link_to(edit_text, edit_path, :remote => true, :class => "spinner")
				html << link_to(delete_text, delete_path, :method => :delete, :class => "spinner", :data => { :confirm => t(:sure) + "?"}, :remote => true)
			end
		end
		# the standard-exporters are listed here
		if not @add_existing_model
			image = icon("icon-external-link")
			html << link_to(image + t(:csv_export), self.send("#{object_name}_path", object, :format => :csv), :class => "spinner")
			image = icon("icon-code")
			html << link_to(image + t(:xml_export), self.send("#{object_name}_path", object, :format => :xml), :class => "spinner")
			image = icon("icon-external-link-sign")
			html << link_to(image + t(:json_export), self.send("#{object_name}_path", object, :format => :json), :class => "spinner")
			html += build_special_buttons(object, link_hash, options)
			split_button(html) # split_button generates a split button (a button with more options)
		else
			content_tag(:span, (checkbox + html.join.html_safe).html_safe, :style => "white-space: nowrap;")
		end
	end
	
	def build_special_controller_buttons(model_class)
		buttons = []
		model_class.has_special_controller_buttons?.each do |option_name, option|
			buttons << special_controller_button(model_class, option_name, option)
		end
		buttons
	end

	def special_controller_button(model_class, option_name, option, link_target = nil)
		link_hash = {}
		link_hash[:special_option] = option_name unless link_target
		link_text = icon(option[:icon]) + t(option[:description])
		if not link_target
			link_target = self.send("#{@controller_name}_path", params.merge(link_hash))
		end
		html_options = {:class => "spinner"}
		html_options[:remote] = true unless option[:non_xhr_link]
		link_to(link_text.html_safe, link_target, html_options) 
	end

	def special_button(option_name, option, link_hash, object = nil)
		object_name = object.class.to_s.underscore
		link_hash[:special_option] = option_name
		link_text = icon(option[:icon]) + t(option[:description])
		link = link_to(link_text.html_safe, self.send("#{object_name}_path", object, link_hash), :remote => true, :class => "spinner")
	end

	def build_special_buttons(object, original_link_hash, options = {})
		html = []
		object.class.has_special_buttons?.each do |option_name, option|
			next if option[:controller_option] # this is for the controller, not the model
			html << special_button(option_name, option, original_link_hash.clone, object)
		end
		html
	end
	
	# legacy stuff
	def build_close_button(link_hash, object_name, object, options = {})
		link_hash = link_hash.clone
		link_hash[:index] = true
		link_hash[:close] = true
		link_text = image_tag("icons/cancel.png", :alt => "close", :class => "icon")
		if options[:non_dropdown_view] # show-view of an object (non-index-view) gets a close-button
			link_text += t(options[:description])
		end
		link = link_to(link_text.html_safe, self.send("#{object_name}_path", object, link_hash), :remote => true) 
		if options[:non_dropdown_view]
			link = link_to(link_text.html_safe, self.send("#{object_name}_path", object, link_hash), :remote => true, :class => "btn btn-default") 
		end
		link
	end

	def close_button(object, options = {})
		link_hash = {}
		link_hash[:ajax_id] = @ajax_id
		link_hash[:index] = true
		link_hash[:close] = true
		button_text = '&times;'.html_safe
		if options[:button_text]
			button_text = options[:button_text]
		end
		html_class = ["close"]
		if options[:button]
			html_class = ["btn", "btn-default", "spinner"]
		end
		object_name = object.class.to_s.underscore
		if options[:non_dropdown_view] 
			if options[:button]
				link = link_to(t(:cancel), self.send("#{object_name}_path", object), :class => "btn btn-default spinner") 
			else
				nil # return nothing, important for empty buttons
			end
		else
			if options[:new]
				link_hash.delete(:index)
				link_to(button_text, self.send("#{object_name}_path", 0, link_hash), :remote => true, :class => html_class.join(" ")) 
			else
				link_to(button_text, self.send("#{object_name}_path", object, link_hash), :remote => true, :class => html_class.join(" ")) 
			end
		end
	end

	# translates database attributes and produces links for sorting
	def translate_and_link(object, attribute)
		name = object.class.human_attribute_name(attribute)
    if attribute.to_s == @order_by
      link_to((content_tag(:span, ' ', :class => "arrow_#{@order_direction}") + name).html_safe, self.send("#{controller_name}_path", params.merge({:order => attribute, :ajax_id => @ajax_id})), :remote => true, :class => "spinner") 
    else
      link_to(name, self.send("#{controller_name}_path", params.merge({:order => attribute, :ajax_id => @ajax_id})), :remote => true, :class => "spinner")
    end
	end
		
	# returns the standard-options for a standard-object
	def get_standard_show_options(object)
		options = []
		options.push(link_to(image_tag('icons/pencil.png', :alt => "edit", :class => "icon") + ' ' + t(:edit), self.send("edit_#{object.class.to_s.underscore}_path", object))) if @right == :write
		options.push(link_to(image_tag('icons/bin_closed.png', :alt => "delete", :class => "icon") + ' ' + t(:delete), object, :method => :delete, :data => { :confirm => t(:sure) + "?"})) if @right == :write
		options
	end

	# obsolet function
	def link_button(link)
		content_tag(:span, link, :class => "link_button")
	end

	# displays attributes according to their values
	def show_attribute_value(object, attribute, options = {})
		description = object.class.attribute_description[attribute]
		value = object.send(attribute)
		if description == :truncate and not options[:show]
			value = value.truncate(50)
		end
		if attribute == :id
			link_to(value, object, :class => "spinner")
		elsif attribute == :_owner_name
			sanitize(value)
		elsif description == :password
      "********"
    elsif description == :method # a special method that displays generic data
			sanitize(value)
    elsif description == :hidden
      nil
		elsif description == :link
			link_to(truncate(value.to_s), value.to_s)
		elsif description.class == Hash and dropdown = description[:dropdown]
			dropdown_object = value
      if dropdown_object
        text = dropdown_object.send(dropdown[:visible_attribute]) 
        dropdown_object.to_yaml
        link_to(text, dropdown_object, :class => "spinner") if text and text != ""
      end
    elsif description.class == Hash and dropdown = description[:predefined_dropdown] # this is just a string, because predefined dropdowns just narrow out specific choices which are defined in the model
      value
		# this is a no more precisely defined dropdown-field that is consisting of a simple 1:n relationship
		elsif object.class.belongs_to?(attribute)
			relation_object = value
			link_to(relation_object.reference_attribute, relation_object, :class => "spinner") if relation_object
		else
			description = object.class.columns_hash[attribute.to_s].type
			case(description)
			when :string
				sanitize(value)
			when :inet
				sanitize(value.to_s)
			when :float
				sanitize(value.to_s)
			when :integer
				sanitize(value.to_s)
			when :boolean
				if value
					icon("icon-ok")
				else
					icon("icon-remove")
				end
			when :time
      	value.strftime("%H:%M")
			when :datetime
				date = value
				begin
					l(date, :format => :shorter)
				rescue
					sanitize(date)
				end
			when :date
				date = value
				begin
					date.to_s(:long)
				rescue
					sanitize(date)
				end
			when :text
				simple_format(value)
				# was: simple_format(value, {}, :sanitize => true)
			else
				flash[:error] = "unknown attribute #{attribute}:#{description}/#{description.class}. Don't know how to handle this"
			end
		end
	end

	# displays attributes in the edit-view
	def edit_attribute_value(object, attribute, form_object, new)
		description = object.class.attribute_description[attribute]
		disabled = object.class.read_only?(attribute, new)
    value = object.send(attribute.to_s)
		logger.info("#{attribute.inspect} / #{description.inspect} / #{value}")
		if attribute == :_color and object.class.colored?
			form_object.collection_select( # this stuff builds the dropdown for us
				:_color, # foreign key of the belongs_to relationship
				Rgb.all, # all elements from the belonged-to class
				:id, # the primary key of the belonged_to class
				:name, # the attribute of the foreign key that we want to see. we could also use a model-function here.
				:include_blank => true
			)
		elsif description == :password
			form_object.password_field(attribute, {:value => value, :class => "form-control"})
		elsif description == :method
			nil
    elsif description == :hidden
      form_object.hidden_field(attribute)
		# this is a rather deprecated form of dropdown, simply use a belongs_to relationship if you want a dropdown from a database
		elsif description.class == Hash and dropdown = description[:dropdown]
			form_object.collection_select( # this stuff builds the dropdown for us
				object.reflections[attribute.to_sym].foreign_key, # foreign key of the belongs_to relationship
				attribute.to_s.camelize.constantize.all, # all elements from the belonged-to class
				attribute.to_s.camelize.constantize.primary_key, # the primary key of the belonged_to class
				dropdown[:visible_attribute] # the attribute of the foreign key that we want to see. we could also use a model-function here.
			)
    elsif description.class == Hash and dropdown = description[:predefined_dropdown]
      options = dropdown.map do |m|
        [m, m]
      end
      form_object.select(attribute, options_for_select(options, :selected => value))
		# this is just a belongs-to relationship that will be shown as a dropdown.
		elsif object.reflections[attribute.to_sym] and object.reflections[attribute.to_sym].macro == :belongs_to
			foreign_key = object.reflections[attribute.to_sym].foreign_key
			base_class = attribute.to_s.camelize.constantize
			form_object.collection_select(
				foreign_key,
				base_class.order(base_class.default_order.join(" ")).all,
				base_class.primary_key,
				:reference_attribute,
				{ :include_blank => (not object.send(foreign_key) or new) },   # if the object is new and not pre-filled, show a form with an empty default value.
				:disabled => disabled,
				:class => "form-control",
			)
		else
			description = object.class.columns_hash[attribute.to_s].type
			html_default_options = {:disabled => disabled, :class => 'form-control'}
			case(description)
			when :string
				form_object.text_field attribute, html_default_options
			when :float
				form_object.number_field attribute, html_default_options.merge({:step => "any"})
			when :inet
				form_object.text_field attribute, html_default_options
			when :integer
				form_object.number_field attribute, html_default_options
			when :boolean
				form_object.check_box attribute, html_default_options
			when :text
				if not value 
					value = ""
				end
				form_object.text_area(attribute, html_default_options.merge({:cols => 25, :rows => (value.lines.count + 3)}))
			when :time
      	content_tag(:span, form_object.time_select(attribute, :include_blank => true), :class => "tiny_input_width form-control")
			when :datetime
      	content_tag(:span, form_object.datetime_select(attribute, :minute_step => 15, :include_blank => true), :class => "tiny_input_width form-control")
			when :date
      	content_tag(:span, form_object.date_select(attribute), :class => "tiny_input_width form-control")
			else
				"sorry, unknown attribute: #{description}"
			end
		end
	end

  def index_path(object)
    self.send("#{object.class.name.tableize}_path")
  end

	# gets the css class of the tr, includes color-matching
	def get_tr_css_style(object, colors)
		tr_class = cycle("tr_even", "tr_odd")
		style = "class=\"#{tr_class}\""
		color = get_model_color(object, colors)
		if color
			style = "style=\"background-color: ##{sanitize(color)};\""
		end
		style.html_safe if style
	end

	# returns the specific color if the model is enabled for 'can_be_colored'
	def get_model_color(object, colors)	
		if object and object.class.colored? and colors and color = colors[object.id] 
			color
		end
	end

	def back_link(object)
		img = icon("icon-circle-arrow-left icon-large")
		link = link_to(img + t(controller_name), index_path(object), :class => "spinner btn btn-default btn-sm")
	end

  # finds the relation between objects, and returns corresponding links
  def object_relation_link(object, relation, close = false)
		return nil if @add_existing_model # we don't want to see any object-relation-links if we look at a m:n table
		relationship_class = relation.to_s.classify.constantize
		return nil if not relationship_class.show_relation?(object)
    relationship = object.reflections[relation].macro
    # relationship can contain :belongs_to, :has_many, etc
		logger.info("relationship detected: #{relationship} / #{relationship.class}")
    if relationship == :belongs_to
			foreign_object = object.send(relation)
			if foreign_object
				title_prefix = foreign_object.class.model_name.human
				title = content_tag(:span, "#{title_prefix}: #{foreign_object.title}".html_safe, :class => "label label-default label-listing")
				title = (icon("icon-expand icon-large icon-rotate-180") + title).html_safe
				content_tag(:div, link_to(title, foreign_object, :class => "no-text-decoration spinnner"), :class => "left-aligned")
			else
				nil
			end
    else
			relation_elements = 0
			if relationship == :has_one
				relation_elements = 1 if object.send(relation)
				pluralized_relation = relation.to_s.pluralize.to_sym # attention: from now on we need the relation pluralized!
			else
				logger.info("relation is: #{relation}")
      	relation_elements = object.send(relation).size
				pluralized_relation = relation
			end
			open = ""
			open_status = "icon-expand icon-large"
			if close
				open = "open_"
				ajax_id = @ajax_id
				open_status = "icon-collapse icon-large" 
			else
				ajax_id = get_ajax_id(true) # get_ajax_id can be called directly from the controller because of  helper_method :get_ajax_id in the application-controller
			end
			link_text = t(pluralized_relation.to_sym) +  content_tag(:span, relation_elements, :id => "dropdown_counter_#{ajax_id}", :class => "badge")
			link_text = (icon(open_status) + " " + content_tag(:span, link_text.html_safe, :class => "label label-primary label-listing")).html_safe
      link = link_to(link_text, self.send("#{pluralized_relation}_path", {
				:ajax_id => ajax_id, 
				:from_show_table => object.class.name.tableize, 
				:show_id => object.id,
				:show_relation => relation,
				:close => close
			}), :remote => true, :class => "spinner no-text-decoration")
			content_tag(:div, link, :id => "#{open}dropdown_#{ajax_id}", :class => "left-aligned")
    end
  end

  # creates the necessary variables for an index-view
  def render_index_view(myclass, elements, options)
    @objects = elements
    @fields = myclass.index_fields
    @model_class = myclass
    @controller_name = @model_class.name.tableize
    # @suppress_new_button = true
		if options[:just_the_table]
    	render :partial => "layouts/index_table"
		else
    	render :file => "layouts/index"
		end
  end

	# returns a special column style tag if defined in the model.
	def column_style(model_class, field)
		if style_info = model_class.column_style(field)
			style = ""
			if style_info == :nowrap
				style << "white-space: nowrap;"
			end
			"style=\"#{style}\"".html_safe
		end
	end

  def dialog(title, body, width = 350, height = 350, div_id = 'popup', position = "center")
    html = "$('#dialog').remove();"
    html << "$('##{div_id}').html('#{escape_javascript('<div id="dialog" title="' + title + '">'.html_safe + body + '</div>'.html_safe)}');"
    html << "$('#dialog').dialog({
      autoOpen: false,
      width: #{width},
      height: #{height},
      position: { my: \"#{position}\", at: \"#{position}\" }
    });"
    html << "$('#dialog').dialog('open');"
    html.html_safe
  end 

	# creates a bootstrap dialog
	def modal(title, body, *dummy)
		html = ""
		html << ajax_html('#popup', render(:file => "layouts/modal", :handlers => [:erb], :locals => {:title => title, :body => body}), false)
		# html << "$('#modal_#{@ajax_id}').modal().css({position: 'fixed', width: 'auto'});"
		# html << "$('#modal_#{@ajax_id}').modal().css({ width: 'auto', 'margin-left': function () { return -($(this).width() / 2); }});"
		html << "$('#modal_#{@ajax_id}').modal();"
		html.html_safe
	end

	# deprecated: no longer used, can be removed soon
	def help_link(object, attribute) 
		if object.class.help_text(attribute)
			ajax_id = get_ajax_id(true)
			html_id = "help_#{attribute}_#{ajax_id}"
			link = link_to(image_tag("icons/lightbulb.png", :class => "icon"), 
				'#',
				:id => html_id, 
				"data-content" => t(object.class.help_text(attribute.to_sym)),
				"data-title" => object.class.human_attribute_name(attribute),
				"data-toggle" => "popover",
				"data-placement" => "top"
			)
			js = content_tag(:script, "$('##{html_id}').popover();".html_safe)
			(link + js).html_safe
		end
	end

  # provides an ajax update to any div id. it also uses fancy ajax-animations thx to jquery. 
  def ajax_html(div_id, body, slide = true) 
    element = "$('#{div_id}')"
		html = "#{element}.empty();" 
		html << "#{element}.html('#{escape_javascript(body)}');" 
		if slide
			html << ajax_slidedown(div_id) 
		else
			html << ajax_show(div_id)
		end
		html.html_safe
  end

	def ajax_show(div_id)
		"$('#{div_id}').show();".html_safe
	end

	def ajax_slidedown(div_id)
		if Rails.configuration.inki.scrollyness
			"$('#{div_id}').slideDown(400, function(){ $('#waiting_bar').fadeOut(1000); });".html_safe
		else
			ajax_show(div_id)
		end
	end

	def ajax_append(div_id, body)
    element = "$('#{div_id}')"
    "#{element}.append('#{escape_javascript(body)}');".html_safe
	end

	def ajax_hide(div_id, delay = 400)
		"$('#{div_id}').hide();".html_safe
	end

	# closes an ajax-element by 'rolling it up'
  def ajax_close(div_id) 
		if Rails.configuration.inki.scrollyness
    	element = "$('#{div_id}')"
    	"#{element}.slideUp(400, function(){ $('#waiting_bar').fadeOut(1000); });".html_safe
		else
			ajax_hide(div_id)
		end
	end

	# decrement a string that is supposed to be an integer :) 
	def ajax_decrement(div_id)
		"counter = parseInt($('#{div_id}').text());
		$('#{div_id}').html(counter-1);".html_safe
	end

	# increment a string that is supposed to be an integer :) 
	def ajax_increment(div_id)
		"counter = parseInt($('#{div_id}').text());
		$('#{div_id}').html(counter+1);".html_safe
	end

	# translates a given object depending on it's state (create model_name or update model_name) 
	def submit_default_value(object)
		object = object.respond_to?(:to_model) ? object.to_model : object
		key    = object ? (object.persisted? ? :update : :create) : :submit

		model = if object.class.respond_to?(:model_name)
			object.class.model_name.human
		else
			"unknown"
		end

		defaults = []
		#defaults << :"helpers.submit.#{object_name}.#{key}"
		defaults << :"helpers.submit.#{key}"
		defaults << "#{key.to_s.humanize} #{model}"

		I18n.t(defaults.shift, :model => model, :default => defaults)
	end


end
