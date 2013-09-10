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
		controller_name = controller_name.to_s
		if self.menu_string == controller_name
			return true
		elsif self.has_submenus?
			self.submenu.each do |sub|
				success = sub.is_active_subtree_for?(controller_name)
				return true if success
			end
		end
		return false
	end

	def first_submenu_entry
		self.submenu.first if self.submenu
	end

	def has_submenus?
		if self.submenu.class == Array and self.submenu.size > 0
			true
		end
	end

	# returns the type of the menu entry
	def menu_type
		if self.klass
			:entry
		else
			:container
		end
	end

	# reduces the menu according to the rights of the user
	def merge_with_rights!(rights)
		if rights[:all]
			return
		end
		allowed_controllers = rights.keys.collect do |controller|
      right = rights[controller] 
      if right == :read or right == :write
        controller
      end
		end
		self.submenu = self.menu_elements
		remove_unmatched_elements(self, allowed_controllers)
	end

	def remove_unmatched_elements(submenu, allowed_controllers)
		if submenu.menu_type == :entry
			if not allowed_controllers.member?(submenu.menu_string)
				Rails.logger.info("removing #{submenu.menu_string}")
				return true
			else 
				return false
			end
		elsif submenu.menu_type == :container
			submenu.submenu = submenu.submenu.delete_if do |sub|
				remove_unmatched_elements(sub, allowed_controllers)
			end
			Rails.logger.info("remaining submenu: #{submenu.submenu.to_yaml}")
		end
		false
	end

end
