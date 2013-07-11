class YamlUser < ActiveRecord::Base

	def self.authenticate(username, digest)
		yaml_auth_source = "#{Rails.root}/config/yaml_auth.yml"
		if not File.exist?(yaml_auth_source)
			logger.error("no yaml auth config file: #{yaml_auth_source}")
			return nil
		end
		yaml_auth = YAML.load(File.read(yaml_auth_source))[Rails.env]
		if not yaml_auth 
			logger.error("yaml auth config seems to have problems. check #{Rails.root}/config/yaml_auth.yml.")
			return nil
		end
		yaml_auth.keys.each do |group|
			logger.info("inspecting group #{group} with digest #{digest}: #{yaml_auth[group][username].inspect}")
			if yaml_auth[group][username] and yaml_auth[group][username]["password"] == digest
				logger.info("user #{username} authenticated successfully against yaml auth source.")
				user = OpenStruct.new
				user.name = yaml_auth[group][username]["name"]
				user.id = username
				user.mailaddress = yaml_auth[group][username]["mailaddress"]
				user.usergroup = OpenStruct.new
				user.usergroup.name = group
				return user
			end
		end
		return nil
	end

end
