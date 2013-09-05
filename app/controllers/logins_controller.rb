class LoginsController < ApplicationController
  skip_before_filter :authorize, :only => [:index, :create, :destroy]
  skip_before_filter :get_colors

  def index
    @menu_items = []
  end

  def create 
		reset_session
		user = Auth.authenticate(params[:username], params[:password], Rails.configuration.inki.auth_source)
    @menu_items = []
    if user
      session[:user_id] = user.mailaddress
      session[:user_name] = user.name
      session[:user_mailaddress] = user.mailaddress
      session[:group] = user.usergroup.name
      session[:undo] = OpenStruct.new
			if uri = session[:request_uri]
				redirect_to uri
				session.delete(:request_uri)
			else
      	redirect_to :controller => "startpages"
			end
    else
      flash[:error] = t(:wrong_username_or_password)
      redirect_to logins_path
    end
  end

  def destroy
    #session.delete(:user_id)
    #session.delete(:user_name)
    #session.delete(:user_mailaddress)
    #session.delete(:group)
		reset_session
    redirect_to :action => "index"
  end

end
