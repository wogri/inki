class IconsController < ApplicationController

	def show_icons
		Dir.chdir "#{Rails.root}/app/assets/images/icons/"
		@files = Dir.glob("*.png").sort
	end

end
