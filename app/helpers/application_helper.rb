# -*- encoding : utf-8 -*-
module ApplicationHelper

	# builds a menu around the menu model and runs generate_menu_html
	def generate_menu(menu)
		return nil if not @menu or not @menu.menu_elements
		@menu.menu_elements.map do |sub_menu|
			generate_menu_html(sub_menu)
		end.join("\n").html_safe
	end

	# generates a bootstrap 3.0 menu
	def generate_menu_html(sub_menu, menu_index = 0)
		link_html_class = []
		li_html_class = []
		html_options = {}
		link_target = '/#'
		html = ""
		text = if sub_menu.menu_type == :container
			t(sub_menu.menu_string)
		elsif sub_menu.menu_type == :entry
			link_target = self.send(sub_menu.url_for_path)
			name = sub_menu.klass.model_name.human(:count => 2) # get the pluralized form of the model name
			if sub_menu.klass.inki_icon
				icon(sub_menu.klass.inki_icon, name, :class => "fa-fw")
			else
				name
			end
		end
		if sub_menu.depth == 1 # main menu entries
			text = (text + " " + content_tag(:b, nil, :class => "caret")).html_safe
			if x = sub_menu.is_active_subtree_for?(controller_name)
				logger.info("found active submenu: #{x} in controller #{controller_name}")
				li_html_class << "active"
			end
			html_options["data-toggle"] = "dropdown"
			link_html_class << "dropdown-toggle"
		end
		link = link_to(text, link_target, html_options.merge(:class => link_html_class.join(" ")))
		index = 0
		if sub_menu.has_submenus? and sub_menu.depth == 1
			li_html_class << "dropdown"
			sub_submenus = sub_menu.submenu.map do |sub_submenu|
				index += 1
				generate_menu_html(sub_submenu, index)
			end.join("\n").html_safe
			html << link
			html << content_tag(:ul, sub_submenus, :class => "dropdown-menu")
			content_tag(:li, html.html_safe, :class => li_html_class.join(" "))
		elsif sub_menu.has_submenus? and sub_menu.depth > 1
			html << content_tag(:li, nil, :class => "divider") unless menu_index == 1
			html << content_tag(:li, text, :class => "dropdown-header")
			html << sub_menu.submenu.map do |sub_submenu|
				index += 1
				generate_menu_html(sub_submenu, index)
			end.join("\n")
			html
		elsif sub_menu.menu_type == :entry
			content_tag(:li, link)
		end
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
			html << link_to(icon("reorder", t(:show), :class => "fa-fw"), self.send("#{object_name}_path", object, link_hash), :remote => true, :class => "btn btn-sm btn-default spinner")
			html << link_to(icon("reorder", t(:show_no_remote), :class => "fa-fw"), self.send("#{object_name}_path", object, link_hash), :class => "spinner") if not @add_existing_model
		end
		if @right == :write and not @add_existing_model # add_existing_model means a has_and_belongs_to_many realtionship selection view :) 
			edit_text = (icon("pencil", t(:edit), :class => "fa-fw")).html_safe
			edit_path = self.send("edit_#{object_name}_path", object, link_hash)
			delete_text = icon("trash", t(:delete), :class => "fa-fw")
			delete_hash = link_hash.clone
			delete_hash.merge!({:page => @page}) if @page and @page.to_i > 0
			delete_hash.merge!({:search => @search_string}) if @search_string and @search_string != ""
			delete_path = self.send("#{object_name}_path", object, delete_hash)
			if options[:non_dropdown_view]
				html << link_to(edit_text, edit_path, :class => "btn btn-default btn-sm spinner")
				html << link_to(delete_text, delete_path, :method => :delete, :class => "spinner", :data => { :confirm => t(:sure) + "?"})
			else
				html << link_to(edit_text, edit_path, :remote => true, :class => "spinner")
				html << link_to(delete_text, delete_path, :method => :delete, :class => "spinner", :data => { :confirm => t(:sure) + "?"}, :remote => true)
			end
			if object.class.is_expirable?
				expirable_text = icon("trash", t(:delayed_delete), :class => "fa-fw")
				expirable_path = self.send("#{object_name}_path", object, :popup => "expire", :ajax_id => @ajax_id) # expire means: return a modal with a popup of expirable time
				html << link_to(expirable_text, expirable_path, :remote => true)
			end
			if object.class.is_versioned?
				version_text = icon("mail-reply-all", t(:versions), :class => "fa-fw")
				version_path = self.send("#{object_name}_path", object, :vcs => true, :ajax_id => @ajax_id) # vcs means: return a modal with a popup of model versions
				html << link_to(version_text, version_path, :remote => true)
			end
		end
		# the standard-exporters are listed here
		if not @add_existing_model
			html << link_to(icon("external-link", t(:csv_export), :class => "fa-fw"), self.send("#{object_name}_path", object, :format => :csv), :class => "spinner")
			html << link_to(icon("code", t(:xml_export), :class => "fa-fw"), self.send("#{object_name}_path", object, :format => :xml), :class => "spinner")
			html << link_to(icon("external-link-square", t(:json_export), :class => "fa-fw"), self.send("#{object_name}_path", object, :format => :json), :class => "spinner")
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
		link_text = icon(option[:icon], t(option[:description]), :class => "fa-fw")
		if not link_target
			link_target = self.send("#{@controller_name}_path", params.symbolize_keys.merge(link_hash))
		end
		html_options = {:class => "spinner"}
		html_options[:remote] = true unless option[:non_xhr_link]
		link_to(link_text.html_safe, link_target, html_options) 
	end

	def special_button(option_name, option, link_hash, object = nil)
		object_name = object.class.to_s.underscore
		link_hash[:special_option] = option_name
		link_text = icon(option[:icon], t(option[:description]), :class => "fa-fw")
		link = link_to(link_text, self.send("#{object_name}_path", object, link_hash), :remote => true, :class => "spinner")
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
    html = ''
    if attribute.to_s == @order_by
      html = icon("caret-down", ' ')
      if @order_direction == "DESC"
        html = icon("caret-up")
      end
      html += " "
    end
    (html.html_safe + link_to(name, self.send("#{controller_name}_path", params.symbolize_keys.merge({:order => attribute, :ajax_id => @ajax_id})), :remote => true, :class => "spinner")).html_safe
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
			foreign_key = object.send(object.class.reflections[attribute.to_s].foreign_key)
			relation_object = attribute.to_s.classify.constantize.unscoped.where(id: foreign_key).first if foreign_key
			# here we go
			link_to(relation_object.reference_attribute, relation_object, :class => "spinner") if foreign_key and relation_object
		else
			columns_hash = object.class.columns_hash
      if columns_hash and columns_hash[attribute.to_s]
        description = columns_hash[attribute.to_s].type 
      else 
        description = nil
      end
			case(description)
			when :string
				sanitize(value)
			when :inet
				sanitize(value.to_s)
			when :float
				sanitize(value.to_s)
			when :cidr
				unless object.nil?
					# we use this rails internal function called _before_type_cast to actually get the subnet mask in the output
          method_before_type_cast = attribute.to_s + "_before_type_cast"
          if object.respond_to?(method_before_type_cast)
            sanitize(object.send(method_before_type_cast).to_s)
					else
						sanitize(value.to_s)
          end
				end
			when :integer
				sanitize(number_with_delimiter(value).to_s)
			when :boolean
				if value
					icon("ok")
				else
					icon("remove")
				end
			when :time
      	value.strftime("%H:%M") if value
			when :datetime
				date = value
				begin
					l(date, :format => :shorter)
				rescue
					sanitize(date.to_s)
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
	def edit_attribute_value(object, attribute, form_object, new, options = {})
		description = object.class.attribute_description[attribute]
		readonly = object.class.read_only?(attribute, new)
		readonly = object.class.is_encrypted?(attribute) if not readonly and not new and not @decryption_success
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
		elsif attribute == :_inki_password  or attribute == :_inki_password_confirmation
			form_object.password_field(attribute, {:value => '', :class => "form-control"})
		elsif description == :password
			form_object.password_field(attribute, {:value => value, :class => "form-control"})
		elsif description == :method
			nil
    elsif description == :hidden
      form_object.hidden_field(attribute)
		# this is a rather deprecated form of dropdown, simply use a belongs_to relationship if you want a dropdown from a database
		elsif description.class == Hash and dropdown = description[:dropdown]
			form_object.collection_select( # this stuff builds the dropdown for us
				object.class.reflections[attribute.to_s].foreign_key, # foreign key of the belongs_to relationship
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
		elsif object.class.belongs_to?(attribute)
			foreign_key = object.class.reflections[attribute.to_s].foreign_key
			base_class = attribute.to_s.camelize.constantize
			form_object.collection_select(
				foreign_key,
				base_class.order(base_class.default_order.join(" ")).to_a,
				base_class.primary_key,
				:reference_attribute,
				{ :include_blank => (not object.send(foreign_key) or new) },   # if the object is new and not pre-filled, show a form with an empty default value.
				:readonly => readonly,
				:class => "form-control",
			)
		else
			description = object.class.columns_hash[attribute.to_s].type
			html_default_options = {:readonly => readonly, :class => 'form-control'}
			case(description)
			when :string
				form_object.text_field attribute, html_default_options
			when :float
				form_object.number_field attribute, html_default_options.merge({:step => "any"})
			when :inet
				form_object.text_field attribute, html_default_options
			when :cidr
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
      	content_tag(:span, form_object.time_select(attribute, :include_blank => true))
			when :datetime
				if object.class.datetime_with_default?(attribute)
      		content_tag(:span, form_object.datetime_select(attribute, :minute_step => 15, :default => Time.now))
				else
      		content_tag(:span, form_object.datetime_select(attribute, :minute_step => 15, :include_blank => true))
				end
			when :date
      	content_tag(:span, form_object.date_select(attribute, :include_blank => true))
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
		link = link_to(icon("circle-arrow-left", t(controller_name)), index_path(object), :class => "spinner btn btn-default btn-sm")
	end

  # finds the relation between objects, and returns corresponding links
  def object_relation_link(object, relation, close = false)
		return nil if @add_existing_model # we don't want to see any object-relation-links if we look at a m:n table
		relationship_class = relation.to_s.classify.constantize
		return nil if not relationship_class.show_relation?(object)
    relationship = object.rails_relation(relation)
    # relationship can contain :belongs_to, :has_many, etc
		logger.info("relationship detected: #{relationship} / #{relationship.class}")
    if relationship == :belongs_to
			foreign_object = object.send(relation)
			if foreign_object
				title_prefix = foreign_object.class.model_name.human
				title = "#{title_prefix}: #{foreign_object.model_title}"
				title = icon("plus-square", title, :class => "fa-lg")
				content_tag(:div, link_to(title, foreign_object, :class => "list-group-item info spinnner"), :class => "list-group-inki list-group")
			else
				nil
			end
    else
			relation_elements = 0
			if relationship == :has_one
				relation_elements = 1 if object.send(relation)
				pluralized_relation = relation.to_s.pluralize.to_sym # attention: from now on we need the relation pluralized!
			else # has many, has_and_belongs_to_many, has_many_through
				logger.info("relation is: #{relation}")
      	relation_elements = object.send(relation).size
				pluralized_relation = relation
			end
			open = ""
			open_status = "plus-square"
			if close
				open = "open_"
				ajax_id = @ajax_id
				open_status = "minus-square" 
			else
				ajax_id = get_ajax_id(true) # get_ajax_id can be called directly from the controller because of  helper_method :get_ajax_id in the application-controller
			end
			
			link_text = content_tag(:span, relation_elements, :id => "dropdown_counter_#{ajax_id}", :class => "badge") + icon(open_status, Object.const_get(relation.to_s.singularize.camelize).model_name.human(:count => relation_elements), :class => "fa-lg")
      link = link_to(link_text, self.send("#{pluralized_relation}_path", {
				:ajax_id => ajax_id, 
				:from_show_table => object.class.name.tableize, 
				:show_id => object.id,
				:show_relation => relation,
				:close => close
			}), :remote => true, :class => "spinner no-text-decoration list-group-item active")
			list_group = content_tag(:div, link, :class => "list-group-inki list-group")
			element = content_tag(:div, list_group)
			content_tag(:div, element, :id => "#{open}dropdown_#{ajax_id}") # important for ajax
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
  def ajax_html(div_id, body, slide = true, options = {}) 
    element = "$('#{div_id}')"
		ajax_method = if options[:replace] 
			"replaceWidth"
		else
			"html"
		end
		html = "#{element}.#{ajax_method}('#{escape_javascript(body)}');" 
		if slide
			html << ajax_slidedown(div_id) 
		else
			html << ajax_show(div_id)
		end
		html.html_safe
  end

	def ajax_replace(div_id, body, slide = true)
		ajax_html(div_id, body, slide, :replace => true)
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

  # creates a xhr link for adding or removing a filter
  def filter_link(model_class, attribute, params, ajax_id)
    filter = params[:filter].clone
    if not filter or filter == ""
      filter = {}
    end
    filter[filter.keys.sort.last.to_i + 1] = {:attribute => attribute, state: "new"}
    description = model_class.human_attribute_name(attribute)
    link = link_to(description, params.symbolize_keys.merge("filter" => filter, :ajax_id => ajax_id), :remote => true, :class => "spinner", :role => "menuitem")
    return content_tag(:li, link, role: "presentation")
  end

  # shows the filter criteria.
  def show_filter(model_class, params, selected_attributes)
    filter = params[:filter].clone
    if not filter or filter == ""
      filter = {}
    end
    html = ""
    filter.keys.sort.each do |key|
      element = filter[key]
      new_filter = filter.clone
      new_filter.delete(key)
      attribute = element["attribute"]
      state = element["state"]
      # remove elements from the dropdown list that have been specified to the most detail.
      if (["datetime_equal", "number_eq", "is"].member?(state) and element["input"] and element["input"] != "") or (state =~ /\Areference_/) or ["boolean_true", "boolean_false"].member?(state)
        selected_attributes.push(attribute.to_sym)
      end
      minus_sign = link_to(icon("minus-circle"), params.symbolize_keys.merge(:filter => new_filter), :remote => true, :class => "spinner btn btn-danger")
      # minus_sign = content_tag(:span, minus_sign, :class => "input-group-btn")
      attribute_name = content_tag(:button, model_class.human_attribute_name(attribute), "class" => "btn btn-default", :type => "button")
      # attribute_name = content_tag(:span, attribute_name.html_safe, :class => "input-group-btn")
      row_content = (minus_sign + attribute_name).html_safe
      input_tag = ""
      dropdown, input_tag = filter_dropdown(model_class, attribute, filter, key)
      row_content << dropdown.html_safe
      row_content = content_tag(:div, row_content.html_safe, :class => "input-group-btn")
      row_content << input_tag.html_safe
      row_content = content_tag(:div, row_content.html_safe, :class => "input-group input-group-sm")
      row = content_tag(:div, row_content, :class => "col-md-12")
      html << content_tag(:div, row, :class => "row")
      # only do this if the show_filter has selected an EQUALS.
      # selected_attributes.push(attribute.to_sym)
    end
    return html.html_safe
  end

  # creates a dropdown for a filter according to the attribute - e. g. "is or contains" for strings, "greater, equal, less than" for integers, etc...
  def filter_dropdown(model_class, attribute, filter, key)
    if model_class.belongs_to?(attribute)
			foreign_key = model_class.reflections[attribute.to_s].foreign_key
			base_class = attribute.to_s.camelize.constantize
			elements = base_class.order(base_class.default_order.join(" "))
      # base_class.primary_key is the primary key
      filter_elements = []
      elements.each do |element|
        id = element.send(base_class.primary_key)
        filter_elements.push({"reference_#{id}".to_sym => element.reference_attribute})
      end
      html = filter_dropdown_button(filter, attribute, key, filter_elements)
      return [html.html_safe, ""]
    end
    attribute_type = model_class.columns_hash[attribute.to_s].type
    html = ""
    input_tag = ""
    # http://api.rubyonrails.org/classes/ActionView/Helpers/FormTagHelper.html
    filter_buttons = []
    if attribute_type == :text or attribute_type == :string
      filter_buttons = [
        {is: I18n.t(:is_equal)}, 
        {contains: I18n.t(:contains)}, 
        {does_not_contain: I18n.t(:does_not_contain)}, 
        {starts_with: I18n.t(:starts_with)}, 
        {ends_with: I18n.t(:ends_with)}, 
        {regex: I18n.t(:regex)}
      ]
      input_tag = text_field_tag("filter[#{key}][input]", filter[key]["input"], :class => "form-control filter_input", :placeholder => I18n.t(:search_text)).html_safe
		elsif attribute_type == :datetime or attribute_type == :date
      filter_buttons = [
        {datetime_greater: I18n.t(:datetime_greater_or_equal)}, 
        {datetime_less: I18n.t(:datetime_less_or_equal)},
        {datetime_equal: I18n.t(:datetime_equal)}
      ]
      placeholder = "#{DateTime.now.to_s(:db)} #{I18n.t(:or)} #{Date.today.to_s(:db)}"
      input_tag = text_field_tag("filter[#{key}][input]", filter[key]["input"], :class => "form-control filter_input", :placeholder => placeholder).html_safe
		elsif attribute_type == :time
      filter_buttons = [
        {datetime_greater: I18n.t(:datetime_greater_or_equal)}, 
        {datetime_less: I18n.t(:datetime_less_or_equal)},
        {datetime_equal: I18n.t(:datetime_equal)}
      ]
      input_tag = text_field_tag("filter[#{key}][input]", filter[key]["input"], :class => "form-control filter_input", :placeholder => "15:43:01").html_safe

    elsif attribute_type == :boolean
      filter_buttons = [
        {boolean_true: icon("ok")}, 
        {boolean_false: icon("remove")}
      ]
		elsif attribute_type == :integer
      filter_buttons = [
        {number_ge: "≥"},
        {number_le: "≤"},
        {number_eq: "="}
      ]
      input_tag = number_field_tag("filter[#{key}][input]", filter[key]["input"], :class => "form-control filter_input", :placeholder => 523).html_safe
		elsif attribute_type == :float
      filter_buttons = [
        {number_ge: "≥"},
        {number_le: "≤"},
        {number_eq: "="}
      ]
      input_tag = number_field_tag("filter[#{key}][input]", filter[key]["input"], :class => "form-control filter_input", :placeholder => 523.34, :step => "0.0001").html_safe
    elsif attribute_type == :cidr or attribute_type == :inet
      filter_buttons = [
        {number_ge: "≥"}, 
        {number_le: "≤"}, 
        {number_eq: "="}, 
        {cidr_contains: I18n.t(:contains)}, 
        {cidr_is_contained_within: I18n.t(:is_contained_within)}
      ]
      input_tag = text_field_tag("filter[#{key}][input]", filter[key]["input"], :class => "form-control filter_input", :placeholder => "192.168.0.0/24 or 192.168.0.1").html_safe
    else
      flash[:error] = "unknown attribute #{attribute}:#{attribute_type}. Don't know how to handle this"
    end
    html << filter_dropdown_button(filter, attribute, key, filter_buttons)
    return [html.html_safe, input_tag]
  end

  def filter_dropdown_button(filter, attribute, key, options)
    filter = filter.deep_dup
    state = filter[key.to_s][:state]
    button_text = ''
    if state != "new"
      options.each do |option|
        tag = option.keys.first
        if tag == state.to_sym
          button_text = option.values.first
        end
      end
    else 
      button_text = I18n.t(:select)
    end
    button = content_tag(:button, ("#{button_text} " + content_tag(:span, "", :class => "caret")).html_safe, :class => "btn btn-default dropdown-toggle", :type => "button", "data-toggle" => "dropdown", "aria-expanded" => true)
    elements = options.collect do |option|
      description = option.values.first
      tag = option.keys.first
      filter[key.to_s][:state] = tag
      link = link_to(description, params.symbolize_keys.merge("filter" => filter), :remote => true, :class => "spinner", :role => "menuitem")
      content_tag(:li, link, role: "presentation").html_safe
    end
    dropdown = button + content_tag(:ul, elements.join("\n").html_safe, :class => "dropdown-menu", :role => "menu") # , "aria-labelledby" => "filter_#{key}#{attribute}")
    return dropdown.html_safe
    # return content_tag(:div, dropdown.html_safe, :class => "input-group-btn")
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
	
	# displays a bootstrap alert-box
	def alert(type = nil, text = nil)
		dismiss_button = content_tag(:button, "&times".html_safe, :type => "button", "class" => "close", "data-dismiss" => "alert", "aria-hidden" => "true")
		# '<button type="button" class="close" data-dismiss="alert" aria-hidden="true">&times;</button>'.html_safe
		if not text
			if flash[:info]
				text = flash[:info]
				type = "success"
			elsif flash[:error]
				text = flash[:error]
				type = "danger"
			end
		end
		content_tag(:div, dismiss_button + text, :class => "alert alert-#{type} alert-dismissable")
	end

	# shows generic alerts
	def show_alerts
		ajax_html('#alert-box', alert)
	end

  def with_list_div(content, ajax_id)
    content_tag(:div, content, id: "list_#{ajax_id}") 
  end

end
