# -*- encoding : utf-8 -*-
class ApplicationController < ActionController::Base

  protect_from_forgery # prevents CSRF

  before_filter :authorize
	before_filter :set_locale
  before_filter :get_ajax_id
	before_filter :set_class_variables
	before_filter :get_colors, :only => [:index, :destroy, :search]
	helper_method :get_ajax_id # this method is also accessible from views and helpers
	helper_method :get_colors # this method is also accessible from views and helpers

  def show
		@close = params[:close]
		params.delete(:close)
		if @close and params[:index]  # if the close has been issued from the index-view we need to render things differently than in 'new'-view
			@index = true
		end
		if params[:id].to_i == 0 and @close # special close of an object that doesn't exist yet
    	render :file => "layouts/close"
			return
		end
    @object = model_class.find(params[:id])
		@div_id = create_div_id(@object)
		@special_option = params[:special_option]
		# this calls a special controller (the special option name is the controller function) that handles the rendering of the special option.
		self.send(@special_option, @object) if @special_option and model_class.has_special_buttons?[@special_option.to_sym]
		if not @special_render
			@special_render = "#{controller_name}/#{@special_option}"
		end
		respond_to do |format|
    	format.js { 
				if @close
    			render :file => "layouts/close"
				else
					render :file => "layouts/show" 
				end
			}
    	format.html { render :file => "layouts/show" }
    	format.json { render :json => @object }
			format.xml { render :xml => @object }
			format.csv { send_data @object.class.to_csv([@object]) } # TODO: this doesn't work yet. I didn't understand how the guy wrote to_csv, he calls a class-method. 
		end
  end

  def index(options = {:render => true})
    _class = model_class
		@special_option = params[:special_option]
		# this calls a special controller (the special option name is the controller function) that handles the rendering of the special option.
		if @special_option and special_option_description = model_class.has_special_controller_buttons?[@special_option.to_sym]
			if special_option_description[:graph] 
				@special_render = "layouts/graph"
				@special_title = t(controller_name.to_sym)
			else
				self.send(@special_option) if @special_option 
				if not @special_render
					@special_render = "#{controller_name}/#{@special_option}"
				end
			end
		end

    @order_by, @order_direction = _class.default_order
		order = ("#{@order_by} #{@order_direction}")
		ordering_by_belongs_to = nil
		if @from_show_table # if the index-view has been called from a show-table (sub-menu)
			@relation = relation_type
			# on has_one relationships the @show_relation variable needs to be singularized
			if @relation == :has_one
				@show_relation = controller_name.singularize.to_sym
			else
				@show_relation = controller_name.to_sym
			end
			@show_close = params[:close]
		end
		if params[:order]
    	set_sort_order(params[:order])
			@reorder = true
		end
    if session[:order] and session_order = session[:order][controller_name]
      @order_by = session_order[:order_by]
      @order_direction = session_order[:order_direction]
			logger.info("sorting by: #{@order_by.inspect} #{@order_direction.inspect}")
      order = "#{@order_by} #{@order_direction}"
    end
		if @order_by and _class.belongs_to?(@order_by)
			belongs_to_class = @order_by.classify.constantize
			order = "#{belongs_to_class.table_name}.#{belongs_to_class.reference_attribute} #{@order_direction}"
			ordering_by_belongs_to = true
		end
		if @from_show_table and not @add_existing_model # add_existing_model is a 'new button pressed for a has_and_belongs_to_many' relationship.
			if @relation == :has_one
				o = @show_object.send(@show_relation)
				if not o
					@objects = [] 
				else
					@objects = [o]
				end
			else
				@objects = @show_object.send(@show_relation).reorder(order)
			end
		else
			@objects = _class.reorder(order)
		end
		if @search_string = params[:search]
			@objects = @objects.with_query("^#{@search_string}") if @search_string != ''
		end
		logger.info("PAGINATION: #{params[:no_pagination].inspect} / #{params[:no_pagination].class}")
		@no_pagination = params[:no_pagination] == "true"
		if ["json", "xml", "csv"].member? request.format
			@no_pagination = true
		end
		@page = params[:page]
		@page = 1 if @no_pagination
		if @relation != :has_one
			@objects = @objects.page(@page)
			@objects = @objects.per(10000) if @no_pagination
		end
		# if we are ordering by a belongs_to object we need to join tables to set the order right.
		if ordering_by_belongs_to
			@objects = @objects.joins(@order_by.to_sym)
		end
    @fields = model_class.index_fields
    @model_class = model_class
    @controller_name = controller_name.to_sym
		if options[:render]
			respond_to do |format|
				format.js { render :file => 'layouts/index' }
				format.html { render :file => 'layouts/index' }
				format.json { render :json => @objects }
				format.xml { render :xml => @objects }
				format.csv { send_data @objects.to_csv }
				format.png { render_graph_data(@special_option, special_option_description[:graph_options]) if defined? special_option_description }
			end
		end
  end

  def edit
    @object = model_class.find(params[:id])
		@div_id = create_div_id(@object)
    render :file => "layouts/edit"
  end

	def destroy
		object = model_class.find(params[:id])
		flashmsg = "#{object.title if defined? object.title} #{t(:deleted)}."
		object.destroy
		object.destroy_owner!
		#object.dispatch!(:destroy)
		params.delete(:id) # parameter removal is essential for the pagination plugin
		params.delete(:action) # parameter removal is essential for the pagination plugin
		flash[:notice] = flashmsg
		index(:render => false) # call index so ajax-views can re-render the index-view
		@div_id = create_div_id(object)
		respond_to do |format|
			format.js { render :file => 'layouts/destroy' }
			format.html { redirect_to send("#{model_class.name.tableize}_path") }
		end	
	end

	def update
		@object = model_class.find(params[:id])
		@div_id = create_div_id(@object)
		if @add_existing_model # a relationship between a has_and_belongs_to_many relation has been updated
			if params[:associated] # the checkbox has been set
				@object.send(@from_show_table) << @show_object
			else
				@object.send(@from_show_table).delete(@show_object)
			end
			@object.update_owner(@user_id, @user_name)
			#@object.dispatch!(:update)
			@add_existing_model = nil
			@ajax_id = @previous_ajax_id 
			index(:render => false) # call index so the index-view can be refreshed. 
			respond_to do |format|
				format.js { render :file => 'layouts/update_habtm' }
				format.html { render :nothing => true } # actually this will never happen.
			end	
		elsif @object.update_attributes(model_parameters)
			# changed = @object.changed? # this doesn't work with update_attributes
			@object.update_owner(@user_id, @user_name)
			#@object.dispatch!(:update)
			flash[:notice] = "#{@object.title if defined? @object.title} #{t(:updated)}."
			get_colors
			respond_to do |format|
				format.js { render :file => 'layouts/update' }
				format.html { redirect_to @object }
			end	
		else
			render :file => "layouts/edit"
		end
	end

	def create
		@object = model_class.new(model_parameters)
    if @object.save 
			@object.update_owner(@user_id, @user_name)
			#@object.dispatch!(:create)
			@relation = relation_type
			@div_id = create_div_id(@object)
			if @relation == :has_and_belongs_to_many
				show_class.find(@show_id).send(controller_name).send("push", @object)
			end	
			index(:render => false) # call index so ajax-views can re-render the index-view
			get_colors
      flash[:notice] = "#{@object.title if defined? @object.title} #{t(:created)}."
			render :file => 'layouts/create'
    else
      render :file => 'layouts/new'
    end
	end

	def new
		@object = model_class.new
		if @from_show_table # this is a new object UNDER another object, so pre-fill the relation 
			@relation = relation_type
			if @relation != :has_and_belongs_to_many
				@object.send(@from_show_table.classify.underscore + "_id=", @show_id) 
			else
				# the user wants to add an existing model, that means we have to present him an index-view of all available objects. 
				if @add_existing_model
					index(:render => false)
				end
			end
			# check if this is an existing one-to-one relationship or not. If so, the user can not add another one. that simple. 
			if @relation == :has_one and show_class.find(@show_id).send(controller_name.singularize)
				@no_new_object_possible = true
			end
		end
    render :file => "layouts/new"
	end

	#def close
	#	if params[:close] and params[:index]  # if the close has been issued from the index-view we need to render things differently than in 'new'-view
	#		@index = true
	#		@object = model_class.find(params[:id])
	#		@div_id = create_div_id(@object)
	#	end
  #  render :file => "layouts/close"
	#end

	def help_text
    render :file => "layouts/help_text"
	end

	def search
		index
	end

  private

	# renders gluplot data generically - attribute is the table column (string)
	def render_graph_data(attribute, options)
		x_axis = "created_at"
		if x_option = options[:x]
			x_axis = x_option
		end
		elements = model_class.order("#{x_axis} ASC")
		datapoints = []
		elements.each do |element|
			datapoints << "#{element.send(x_axis.to_s).to_time.to_i} #{element.attributes[attribute]}"
		end
		gnuplot(datapoints.join("\n"), :y_axis => model_class.human_attribute_name(attribute))
	end

	# strong parameters abstraction
	def model_parameters
		model_symbol = model_class.to_s.underscore.to_sym
		params.require(model_symbol).permit(model_class.strong_parameters)
	end

	# gnuplot
	def gnuplot(datapoints, options = {})
		expires_now # no caching for you clients
		gnuplot_config=<<EOF
			set terminal png size 800,400
			set xdata time
			set timefmt "%s"
			set grid
			set xlabel "Date"
			set ylabel "#{options[:y_axis] || options[:name]}"
			#{options[:format]}
			set title "#{options[:name]}"
			set key left box 
			plot "-" using 1:2 index 0 title "#{options[:name]}" with lines
EOF
		IO.popen("/usr/bin/gnuplot", 'w+') do |gp|
			gp.write(gnuplot_config)
			gp.write(datapoints)
			gp.close_write
			send_data(gp.read, :type => 'image/png', :disposition => 'inline', :filename => "#{Time.now.to_i}.png")
		end
	end


	# shows source code of an element
	def source_code
		@content = CodeRay.scan_file("#{Rails.root}/app/models/#{controller_name.singularize}.rb", :ruby).div
		@special_title = t(:show_source_code)
		@special_render = "layouts/source_code"
	end

	def create_div_id(object)
		"#{@ajax_id}_#{object.class}_#{object.id}"
	end

	# checks on REST-Ful actions
	def authenticate_restful_request
		shared_password = params[:shared_password]
		if shared_password != Rails.configuration.inki.rest_password
			logger.error("client did not send the correct shared password")
			return false
		else
			return true
		end
	end

	# sets specific class variables which are needed in many views (relations)
	def set_class_variables
		@from_show_table = params[:from_show_table]
		@non_dropdown_view = params[:non_dropdown_view]
		@add_existing_model = params[:add_existing_model]
		@show_id = params[:show_id]
		@show_object = show_class.find(@show_id) if @from_show_table
		@previous_ajax_id = params[:previous_ajax_id]
	end

	# just creates a class out of a specific string, used for relations
	def show_class
		@from_show_table.classify.constantize if @from_show_table
	end

	# returns the type of the relationship between show_class and current controller. used in index-view
	def relation_type
		return if not @from_show_table
		singularized_controller_name = controller_name.singularize.to_sym
		r = show_class.new.reflections[singularized_controller_name]
		if r
			return r.macro
		else
			r = show_class.new.reflections[controller_name.to_sym]
			return r.macro if r
		end
	end

	# used to find out the user for paper_trail
	def user_for_paper_trail
		logger.info("user_for_paper_trail called. current username: #{@user_name}")
		@user_name
	end

	# will return all color information for the current controller, built into a quick hash
	def get_colors
    colors = Color.where(:model_name => model_class.to_s)
		@colors = {}
		colors.each do |color|
			@colors[color.model_id] = color.rgb.rgb if color.rgb
		end
		logger.info("COLORS: #{@colors.to_yaml}")
	end

  # returns a unique number for the calling client. this is used for generating unique div-ids. is called from a before_filter
  def get_ajax_id(new_id = false)
		if params[:ajax_id] and not new_id
    	@ajax_id = params[:ajax_id]
			return
		end
    if not session[:ajax_id]
      session[:ajax_id] = 0 
    end
    @ajax_id = session[:ajax_id] += 1
  end

  def model_class
    controller_name.classify.constantize
  end

	def set_locale
		I18n.locale = params[:locale] || I18n.default_locale
	end

	def default_url_options(options={})
  	logger.debug "default_url_options is passed options: #{options.inspect}\n"
	  { :locale => I18n.locale }
	end

  def authorize
    @user_id = session[:user_id]
    @user_name = session[:user_name]
		@user_group = session[:group]
    if not @user_id 
			request_uri = request.env['REQUEST_URI']
			session[:request_uri] = request_uri if not request_uri =~ /logins/
			if request.xhr?
				render js: "window.location.pathname = #{logins_path.to_json}"
			else
      	redirect_to logins_path
			end
    else
      @menu_items = generate_menu
      @rights = get_rights
      if not @rights # something happened with group-rights - destroy the session so another user can login
        session.delete(:user_id)
        logger.debug("### deleted session info for user login ")
        redirect_to logins_path
        return
      end
      @menu_items = merge_menu_with_rights(@menu_items, @rights)
      @menu_items = [] unless @menu_items
      modifier_rights = ["new", "edit", "create", "update", "destroy"]
      if modifier_rights.member? action_name
        time = Time.now.strftime("%y-%m-%d %H:%M:%S")
        logger.warn("#{time}: User #{@user_name} called action #{action_name} on #{controller_name}: #{controller_name}/#{action_name}/#{params[:id]}")
      end
      if @right != :write and modifier_rights.member? action_name and controller_name != "logins"
        logger.warn("no write-right on #{controller_name}")
        redirect_to :controller => "startpages", :action => "unauthorized"
      end
      if @right != :write and @right != :read
        logger.warn("no right at all on #{controller_name}")
        redirect_to :controller => "startpages", :action => "unauthorized"
      end
    end
  end

   # generating menu by reading it from a yaml file
  def generate_menu 
    # logger.warn("Rails-Root is: #{Rails.root}")
    YAML::load_file("#{Rails.root}/config/menu.yml")
  end

   # return a hash of rights 
  def get_rights
    # logger.warn("Rails-Root is: #{Rails.root}")
    rights = YAML::load_file("#{Rails.root}/config/group_rights.yml")
		if not @user_group
			return nil
		end
    rights = rights[@user_group]
    if not rights
      return nil
    end
    @right = rights[controller_name]
    if not @right and rights[:all]# there is the possiblity that :all controllers takes the default right, and the above rule overwrites the right
      @right = rights[:all]
    end
    rights
  end

  def merge_menu_with_rights(menu, rights)
    if rights[:all] # if this user right is defined - either read or write - all menus will be presented, nothing to do
      return menu
    end
    allowed_controllers = rights.keys.collect do |controller|
      right = rights[controller] 
      if right == :read or right == :write
        controller
      end
    end
		build_menu_with_rights(menu, allowed_controllers)
  end

	def build_menu_with_rights(menu, allowed_controllers, new_menu = [])
		if menu.class == Array
			menu.each do |m|
				menu_item = build_menu_with_rights(m, allowed_controllers)
				new_menu += menu_item if menu_item.size > 0
			end
		elsif menu.class == String and allowed_controllers.member?(menu)
			new_menu.push(menu)
		elsif menu.class == Hash
			first_hash_element = menu[menu.keys.first]
			menu_item = build_menu_with_rights(first_hash_element, allowed_controllers)
			new_menu.push({menu.keys.first => menu_item}) if menu_item.size > 0
		end
		return new_menu
	end

  def set_sort_order(new_order)
    order_by, order_direction = model_class.default_order
    if not session[:order]
      session[:order] = {}
    end
		if not session[:order][controller_name] # this is the case when no default order has been placed. 
			session[:order][controller_name] = {:order_by => order_by, :order_direction => order_direction}
		end
    params.delete(:order) # important so pagination doesn't start linking the sort order.
    if session[:order][controller_name] and session[:order][controller_name][:order_by] == new_order
      if session[:order][controller_name][:order_direction] == "ASC"
        session[:order][controller_name][:order_direction] = "DESC"
      else
        session[:order][controller_name][:order_direction] = "ASC"
      end
    else
      session[:order][controller_name] = {:order_by => new_order, :order_direction => "ASC"}
    end
  end

end
