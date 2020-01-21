# -*- encoding : utf-8 -*-
class ApplicationController < ActionController::Base

  protect_from_forgery # prevents CSRF

  before_action :authorize
	before_action :set_locale
  before_action :get_ajax_id
	before_action :set_class_variables
	before_action :get_colors, :only => [:index, :destroy, :search]
	helper_method :get_ajax_id # this method is also accessible from views and helpers
	helper_method :get_colors # this method is also accessible from views and helpers

  def show
		@close = params[:close]
		@vcs = params[:vcs]
		@popup = params[:popup]
		params.delete(:close)
		if @close and params[:index]  # if the close has been issued from the index-view we need to render things differently than in 'new'-view
			@index = true
		end
		if params[:id].to_i == 0 and @close # special close of an object that doesn't exist yet
      render template: "layouts/close"
			return
		end
    @object = model_class.find(params[:id])
		@div_id = create_div_id(@object)
		@special_option = params[:special_option]
		# if there is a special option set, we have to get different content
		if @special_option and model_class.has_special_buttons?[@special_option.to_sym]
		# this calls a special controller (the special option name is the controller function) that handles the rendering of the special option.
			@special_title = model_class.special_button(@special_option)[:description]
			self.send(@special_option, @object) 
			if not @special_render
				@special_render = "#{controller_name}/#{@special_option}"
			end
		end
		# this is for the version control system. 
		if @vcs 
			if @version_id = params[:version_id]
				@object = ObjectVersion.where(:id => @version_id).first.to_inki_object
			else
				@current_element_selected = true
				@show_version = @object
			end
			if params[:current_element]
				@version_id = 0
			end
		end
		respond_to do |format|
    	format.js { 
				if @close
          render template: "layouts/close"
				else
          render template: "layouts/show" 
				end
			}
      format.html {render template: "layouts/show" }
    	format.json {render :json => @object }
			format.xml {render :xml => @object }
			format.csv {send_data @object.class.to_csv([@object]) }
			format.pdf {send_data @object.to_pdf, 
                  filename: "#{@object.id}.pdf",
                  type: 'application/pdf'}
		end
  end

  def index(options = {:render => true})
    _class = model_class
		@special_option = params[:special_option]
		if @undo = params[:undo]
			create_undo_elements(model_class, @user_id)
		end
		# this calls a special controller (the special option name is the controller function) that handles the rendering of the special option.
		if @special_option and special_option_description = model_class.has_special_controller_buttons?[@special_option.to_sym]
			if special_option_description[:graph] 
				@special_render = "layouts/graph"
				@special_title = _class.model_name.human(:count => 2)
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
    if filter = params[:filter]
      @filter = true
      if filter.class == String
        params[:filter] = {}
      else
        filter.keys.each do |key|
          element = filter[key]
          attribute = element[:attribute].to_sym
          if _class.sorted_attributes.member?(attribute) or _class.belongs_to_hidden_fields(no_id: true).member?(attribute)
            # "filter"=>{"1"=>{"attribute"=>"username", "input"=>"aasdf", "state"=>"is"}},
            input = nil
            input = true if element[:input] and not element[:input].empty?
            logger.info("INPUT is: #{input.inspect}")
            state = element["state"]
            if state == "is" and input
              logger.info("is added.")
              @objects = @objects.where("#{attribute} ILIKE ?", element[:input])
            elsif state == "contains" and input
              @objects = @objects.where("#{attribute} ILIKE ?", "%#{element[:input]}%")
            elsif state == "does_not_contain" and input
              @objects = @objects.where("#{attribute} NOT ILIKE ?", "%#{element[:input]}%")
            elsif state == "starts_with" and input
              @objects = @objects.where("#{attribute} ILIKE ?", "#{element[:input]}%")
            elsif state == "ends_with" and input
              @objects = @objects.where("#{attribute} ILIKE ?", "%#{element[:input]}")
            elsif state == "regex" and input
              @objects = @objects.where("#{attribute} ~ ?", "#{element[:input]}")
            elsif state == "datetime_greater" and input
              @objects = @objects.where("#{attribute} > ?", DateTime.parse("#{element[:input]}"))
            elsif state == "datetime_less" and input
              @objects = @objects.where("#{attribute} < ?", DateTime.parse("#{element[:input]}"))
            elsif state == "datetime_equal" and input
              @objects = @objects.where("#{attribute} = ?", DateTime.parse("#{element[:input]}"))
            elsif state == "boolean_true"
              @objects = @objects.where("#{attribute} IS TRUE")
            elsif state == "boolean_false"
              @objects = @objects.where("#{attribute} IS NOT TRUE")
            elsif state == "number_ge" and input
              @objects = @objects.where("#{attribute} >= ?", "#{element[:input]}")
            elsif state == "number_le" and input
              @objects = @objects.where("#{attribute} <= ?", "#{element[:input]}")
            elsif state == "number_eq" and input
              @objects = @objects.where("#{attribute} = ?", "#{element[:input]}")
            elsif matchdata = state.match(/\Areference_(\d+)\z/)
              foreign_id = matchdata[1]
			        foreign_key = model_class.reflections[attribute.to_s].foreign_key
              @objects = @objects.where("#{foreign_key} = ?",foreign_id)
            elsif state == "cidr_contains" and input
              @objects = @objects.where("#{attribute} >>= ?", "#{element[:input]}")
            elsif state == "cidr_is_contained_within" and input
              @objects = @objects.where("#{attribute} <<= ?", "#{element[:input]}")
            else
              logger.error("uncaught state!")
            end
          else
            logger.error("somebody injected a wrong attribute: #{attribute}")
          end
        end
      end
    elsif @search_string = params[:search]
			@objects = @objects.with_query("^\"#{@search_string}\"") if @search_string != ''
		end
		# When a JSON-Request comes in, that wants to search for something specific (User.where(...)) this search will be implemented here
		if @rest_request 
			@no_pagination = true
			search_hash = {}
			model_class.attribute_names.each do |attr|
				attr = attr.to_sym
				if params[attr]
					search_hash[attr] = params[attr]
				end
			end
			if search_hash.length > 0
				@objects = @objects.where(search_hash)
			end
		end
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
        format.js { render template: "layouts/index" }
        format.html { render template: "layouts/index" }
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
		@show_encryption_passwords = false
    render template: "layouts/edit" 
  end

	def destroy
		object = model_class.find(params[:id])
		flashmsg = "#{object.title if defined? object.title} #{t(:deleted)}."
		object.destroy
		object.destroy_owner!
		#object.dispatch!(:destroy)
		params.delete(:id) # parameter removal is essential for the pagination plugin
		params.delete(:action) # parameter removal is essential for the pagination plugin
		if not defined? @rest_request
			session[:undo].action = :destroy
			session[:undo].model_id = object.id
			session[:undo].model_name = object.class.to_s
			flash[:notice] = flashmsg
		end
		index(:render => false) # call index so ajax-views can re-render the index-view
		@div_id = create_div_id(object)
		respond_to do |format|
      format.js { render template: "layouts/destroy" }
			format.html { redirect_to send("#{model_class.name.tableize}_path") }
			format.json { head :no_content }
		end	
	end

	def update
		@object = model_class.find(params[:id])
		# the object wants to be decrypted
		if params[:unlock_with_password]
			# this is not a real update, it's a decryption. It updates the show view again. 
			@overwrite_div_id = params[:overwrite_div_id]
			@edit_mode = params[:edit_mode]
			@edit_mode = false if @edit_mode == "false"
			begin
				@object.decrypt(params[model_class.name.underscore.to_sym][:_inki_password], Rails.configuration.inki.cipher)
				@decryption_success = true
				flash.now[:info] = t(:decryption_successful)
				@show_encryption_passwords = true
			rescue StandardError => e 
				logger.error(e.to_s)
				@decryption_error = true
				flash.now[:error] = t(:decryption_failed)
			end
			respond_to do |format|
        format.js { render template: "layouts/show" }
			end
			return
		end
		@div_id = create_div_id(@object)
		if @add_existing_model # a relationship between a has_and_belongs_to_many relation has been updated
			if params[:associated] # the checkbox has been set
				@object.send(@from_show_table) << @show_object
			else
				@object.send(@from_show_table).delete(@show_object)
				# unfortunately rails internals can't handle this with a callback, see
				# http://guides.rubyonrails.org/association_basics.html#the-has-and-belongs-to-many-association
				#, so we have to take care of this by ourselves
				@object.dispatch(:update)
				@show_object.dispatch(:update)
			end
			@object.update_owner(@user_id, @user_name)
			@add_existing_model = nil
			@ajax_id = @previous_ajax_id 
			index(:render => false) # call index so the index-view can be refreshed. 
			respond_to do |format|
        format.js { render template: "layouts/update_habtm" }
				format.html { render :nothing => true } # actually this will never happen.
			end	
		elsif @expire = params[:expire]
			expire = params[controller_name.singularize.to_sym]
			date = Date.new expire["created_at(1i)"].to_i, expire["created_at(2i)"].to_i, expire["created_at(3i)"].to_i
			time = date.to_time + 1.day - 1.second
			logger.warn("Will expire #{model_class}/#{@object.id} on #{l(time, format: :short)}")
			if Time.now > time
				flash.now[:error] = t(:you_can_not_expire_an_object_in_the_past)
			else
				flash.now[:info] = t(:your_object_will_expire_on, :time => l(time, format: :short))
				# dispatch this object with the delayed_create method, meaning that the dispatch-job will run at the specified time. 
				@object.dispatch(:operation => "delayed_delete", :retry_at => time)
			end
			respond_to do |format|
        format.js { render template: "layouts/update" }
				format.html { redirect_to @object }
				format.json { head :no_content }
			end	
		elsif @object.update_attributes(model_parameters)
			encrypt(@object)
			@object.update_owner(@user_id, @user_name)
			if not defined? @rest_request
				session[:undo].action = :update
				session[:undo].model_id = @object.id
				session[:undo].model_name = @object.class.to_s
				flash[:notice] = "#{@object.title if defined? @object.title} #{t(:updated)}."
				get_colors
				@undo = params[:undo]
			end
			if @vcs = params[:vcs] and not @undo
				@current_element_selected = true
				@version_id = 0
				@restore = true
				flash.now[:notice] = t(:object_restore_successful)
			end
				#respond_to do |format|
					#format.js { render :file => 'layouts/show' }
				#end
			#else	
			respond_to do |format|
        format.js { render template: "layouts/update" }
				format.html { redirect_to @object }
				format.json { head :no_content }
			end	
			#end	
		else
			if @vcs = params[:vcs]
				@version_id = 0
				@restore = true
				@current_element_selected = true
				flash.now[:error] = t(:could_not_save_element)
				respond_to do |format|
          format.js { render template: "layouts/show" }
				end
			else
				respond_to do |format|
          format.js { render template: "layouts/edit" }
          format.html { render template: "layouts/edit" }
					format.json { render json: @object.errors, status: :unprocessable_entity }
				end
			end
		end
	end

	def create
		@object = model_class.new(model_parameters)
    if @object.save 
			encrypt(@object)
			@object.update_owner(@user_id, @user_name)
			#@object.dispatch!(:create)
			@relation = relation_type
			if not defined? @rest_request
				session[:undo].action = :create
				session[:undo].model_id = @object.id
				session[:undo].model_name = @object.class.to_s
			end
			@div_id = create_div_id(@object)
			@undo = params[:undo]
			if @relation == :has_and_belongs_to_many or @relation == :has_many_through
				show_class.find(@show_id).send(controller_name).send("push", @object)
			end	
			index(:render => false) # call index so ajax-views can re-render the index-view
			get_colors
      flash[:notice] = "#{@object.title if defined? @object.title} #{t(:created)}."
			respond_to do |format|
				format.js { render template: "layouts/create" }
				format.json { render json: @object, status: :created, location: @object }
			end
    else
			@show_encryption_passwords = true
			respond_to do |format|
        format.js { render template: "layouts/new" }
				format.json { render json: @object.errors, status: :unprocessable_entity }
			end
    end
	end

	def new
		@object = model_class.new
		if @from_show_table # this is a new object UNDER another object, so pre-fill the relation 
			@relation = relation_type
			if @relation != :has_and_belongs_to_many and @relation != :has_many_through
				@foreign_key = model_class.reflections[@from_show_table.classify.underscore.to_s].foreign_key
				@object.send("#{@foreign_key}=", @show_id) 
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
		@show_encryption_passwords = true
    render template: "layouts/new" 
	end

  private

	def encrypt(object)
		if object._inki_password
			logger.info("encrypting object, _inki_password found.")
			object.encrypt!(object._inki_password, Rails.configuration.inki.cipher)
		end
	end


	# generate the necessary objects for the undo-operation
	def create_undo_elements(model_class, user_id)
		begin
			if not session[:undo] or not session[:undo].action
				return
			end
			undo_class = session[:undo].model_name.constantize
			if session[:undo].action == :create
				object = undo_class.find(session[:undo].model_id)
			elsif session[:undo].action == :update
				object = undo_class.find(session[:undo].model_id)
				if undo_class.is_versioned?
					object = object.previous_version
				else
					flash.now[:error] = t(:not_versioned_error)
					return
				end
			elsif session[:undo].action == :destroy
				if undo_class.is_versioned?
					version_object = ObjectVersion.where(:inki_model_name => undo_class.to_s, :model_id => session[:undo].model_id, :model_owner_id => user_id).order("created_at DESC").first
					if version_object
						@undo_object = version_object.to_inki_object
						@undo_object.new_record!
					else
						flash.now[:error] = t(:undo_error)
						logger.error("undo error. can't find object version of #{undo_class} / #{session[:undo].model_id}.")
					end
				else
					flash.now[:error] = t(:not_versioned_error)
					return
				end
			end
			@undo_object = object if object and check_undo_ownership(object, user_id) and not session[:undo].action == :destroy
		rescue StandardError => e
			flash.now[:error] = t(:undo_error)
			logger.error(e)
		end

	end

	def check_undo_ownership(object, user_id)
		if object._owner_id == user_id
			true
		else
			flash.now[:error] = t(:other_user_changed_element, :user_name => object._owner_name)
			false
		end
	end

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
		if r = show_class.new.rails_relation(singularized_controller_name)
			return r
		else
			show_class.new.rails_relation(controller_name)
		end
	end

	# used to find out the user for paper_trail
	def user_for_paper_trail
		logger.info("user_for_paper_trail called. current username: #{@user_name}")
		@user_name
	end

	# will return all color information for the current controller, built into a quick hash
	def get_colors
		@colors = {}
		if not ActiveRecord::Base.connection.table_exists? 'colors'
			return
		end
    colors = Color.where(:inki_model_name => model_class.to_s)
		colors.each do |color|
			@colors[color.model_id] = color.rgb.rgb if color.rgb
		end
	end

  # returns a unique number for the calling client. this is used for generating unique div-ids. is called from a before_action
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
		if request.format == Mime[:json] and not @user_id # a way to authenticate via http basic authentication, this is useful for machine generated json / xml requests.
			authenticate_or_request_with_http_basic("inki username and password please") do |username, password|
				if username == "inki" and password == Rails.configuration.inki.rest_password
					@user_id = "inki_rest_request"
					@user_name = "inki_rest_request"
					@user_group = "http_basic"
					@rest_request = true
				elsif Rails.configuration.inki.rest_users and rest_user = Rails.configuration.inki.rest_users[username] and password == rest_user["password"]
					@user_id = rest_user["mail_address"]
					@user_name = rest_user["description"]
					@user_group = rest_user["group"]
					@rest_request = true
				else
					logger.warn "did not allow user '#{username}' to login via json. "
					render json: nil, status: :forbidden
				end
			end
			return if not @user_id
		end
    if not @user_id 
			request_uri = request.env['REQUEST_URI']
			if not ["index", "show"].member?(action_name)
				request_uri = self.send(controller_name + "_path")
			end
			session[:request_uri] = request_uri if not request_uri =~ /logins/
			if request.xhr?
				render js: "window.location.pathname = #{logins_path.to_json}"
			else
      	redirect_to logins_path
			end
    else
      @menu = generate_menu
      @rights = get_rights
      if not @rights # something happened with group-rights - destroy the session so another user can login
        reset_session
        logger.debug("### deleted session info for user login ")
				if @rest_request 
					respond_to do |format|
						format.json { render json: nil, status: :forbidden}
					end
				else
        	redirect_to logins_path
				end
        return
      end
      @menu.merge_with_rights!(@rights)
      modifier_rights = ["new", "edit", "create", "update", "destroy"]
      if modifier_rights.member? action_name
        time = Time.now.strftime("%y-%m-%d %H:%M:%S")
        logger.warn("#{time}: User #{@user_name} called action #{action_name} on #{controller_name}: #{controller_name}/#{action_name}/#{params[:id]}")
      end
      if @right != :write and modifier_rights.member? action_name and controller_name != "logins"
        logger.warn("no write-right on #{controller_name}")
				if @rest_request 
					respond_to do |format|
						format.json { render json: nil, status: :forbidden}
					end
				else
        	redirect_to :controller => "startpages", :action => "unauthorized"
				end
      end
      if @right != :write and @right != :read
        logger.warn("no right at all on #{controller_name}")
				if @rest_request 
					respond_to do |format|
						format.json { render json: nil, status: :forbidden}
					end
				else
        	redirect_to :controller => "startpages", :action => "unauthorized"
				end
      end
    end
  end

   # generating menu by reading it from a yaml file and sending it to the Menu Class
  def generate_menu 
    # logger.warn("Rails-Root is: #{Rails.root}")
    Menu.new(YAML::load_file("#{Rails.root}/config/menu.yml"))
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
