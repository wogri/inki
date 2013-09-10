# implements the menu, able to build recursive stuff
class Menu

	attr_accessor :klass, :icon, :parent, :depth, :menu_string, :submenu, :url_for_path, :root, :menu_elements

	def initialize(menu_config, depth = 0)
		self.depth = depth
		if self.depth == 0 
			self.menu_string = :root
			self.root = true
		end
		depth += 1
		if menu_config.class == Hash
			self.menu_string = menu_config.keys.first
			self.submenu = Menu.new(menu_config[menu_config.keys.first], depth).menu_elements
		elsif menu_config.class == Array 
			depth -= 1 unless self.root # an array is not a depth per se
			self.menu_elements = menu_config.map do |menu_element|
				Menu.new(menu_element, depth)
			end
			if self.root
				self.submenu = self.menu_elements
			end
		elsif menu_config.class == String
			self.menu_string = menu_config.tableize
			self.url_for_path = "#{menu_config.tableize}_path"
			self.klass = Object.const_get(menu_config)
			self.icon = self.klass.inki_icon
		else
			logger.error("unknown class #{menu_config.class} for menu")
		end
	end

	def is_active_subtree_for?(controller_name)
		controller_name.to_s!
		if self.menu_string == controller_name
			return true
		else
			self.submenu.each do |sub|
				if sub.is_active_subtree_for?(controller_name)
					return true
				end
			end
		end
	end

	def first_submenu_entry
		self.submenu.first if self.submenu
	end

	

end
