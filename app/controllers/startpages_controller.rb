# -*- encoding : utf-8 -*-
class StartpagesController < ApplicationController
  skip_before_filter :get_colors

	def index
	end

  def unauthorized
    render :file => "layouts/unauthorized"
  end

end
