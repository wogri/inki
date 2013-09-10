# implements the menu, able to build recursive stuff
class Menu

	attr_accessor :klass, :icon, :parent, :depth, :menu_string, :submenu, :children, :url_for_path, :root

	def initialize(menu_config, depth = 0)
		self.depth = depth
		if depth == 0 
			self.menu_string = :root
			self.root = true
		end
		depth += 1
		if menu_config.class == Hash
			self.menu_string = menu_config.keys.first
			self.submenu = Menu.new(menu_config[menu_config.keys.first])
		end
		if menu_config.class == Array
			menu_elements = menu_config.map do |menu_element|
				Menu.new(menu_element, depth)
			end
		end
		if root
			self.submenu = menu_elements
		else
			return menu_elements
		end
		if menu_config.class == String
			self.menu_string = menu_config.tableize
			self.url_for_path = "#{menu_config.tableize}_path"
			self.klass = Object.const_get(menu_config)
			self.icon = self.klass.inki_icon
		end
	end

end
