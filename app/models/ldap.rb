class Ldap < ActiveRecord::Base

	def self.authenticate(username, password, external_authentication = false)
		ldap_config_file = "#{Rails.root}/config/ldap.yml"
		if not File.exist?(ldap_config_file)
			logger.error("no ldap config file: #{ldap_config_file}")
			return nil
		end
		ldap_config = YAML.load(File.read(ldap_config_file))[Rails.env]
		if not ldap_config or not ldap_config['enabled'] # return if ldap wasn't enabled or the config-file is dirty
			logger.error("ldap config was not enabled (set enabled: true in #{ldap_config_file})")
			return nil
		end
		require 'net/ldap'
		ldap = nil
		begin
			ldap = init_ldap(ldap_config)
		rescue StandardError => e
			logger.error("ldap error: #{e}")
		ensure
			if not ldap
				logger.error("ldap not initialized successfully. sorry.")
				return nil
			end
		end
		authenticated = bind_ldap(ldap, ldap_config, username, password, external_authentication)
		return authenticated if external_authentication
		if authenticated
			logger.info("user #{username} authenticated successfully against ldap.")
			# get the local user from the database, but don't care about the password, it's been set in ldap before
    	user = OpenStruct.new
			ldap_to_userattrib = ldap_config['attribute_mapping']
			ldap_filter = build_ldap_filter(ldap_config, username)
			ldap.search(
				:base => ldap_config['base_dn'],
				:filter => ldap_filter,
				:attributes => ldap_config['attribute_mapping'].values
			) do |entry|
				logger.debug(entry.inspect)
				user.name = entry[ldap_to_userattrib["name"].downcase.to_sym].first
				user.mailaddress = entry[ldap_to_userattrib["mailaddress"].downcase.to_sym].first
				user.id = username
				if static_group = ldap_config['static_group'] 
					user.usergroup = OpenStruct.new
					user.usergroup.name = static_group
				else
					# get the group information from LDAP
					# TODO! 
				end
				logger.debug(user.inspect)
				return user
			end
		else
			logger.error("user #{username} could not authenticate against ldap. Wrong password or user doesn't exist.")
			return nil
		end
	end

	private
	
	# this method is obsolete, we don't sync into the database anymore
	def self.sync_ldap_user_to_db(ldap, ldap_config, username)
		user = User.new
		ldap_to_userattrib = ldap_config['attribute_mapping'].invert
		ldap_filter = build_ldap_filter(ldap_config, username)
		ldap.search(
			:base => ldap_config['base_dn'],
			:filter => ldap_filter,
			:attributes => ldap_config['attribute_mapping'].values
		) do |entry|
			entry.each do |attribute, values|
				if attribute == :dn 
					next
				end
				value = values.first
				logger.info("attrib: #{attribute.inspect} / val: #{value}")
				logger.info(ldap_to_userattrib.to_yaml)
				user.send(ldap_to_userattrib[attribute.to_s] + "=", value)
			end
		end
		user.save(:validate => false)
		user
	end

	def self.build_ldap_filter(ldap_config, username, external_authentication = false)
		login_filter = Net::LDAP::Filter.eq(ldap_config["attribute_mapping"]["username"], username)
		ldap_filter = login_filter
		if not external_authentication
			ldap_config["user_filter"].keys.each do |filter|
				user_filter = Net::LDAP::Filter.eq(filter, ldap_config["user_filter"][filter])
				ldap_filter = Net::LDAP::Filter.join(ldap_filter, user_filter)
			end
		end
		ldap_filter
	end

	def self.bind_ldap(ldap, ldap_config, username, password, external_authentication)
		ldap_filter = build_ldap_filter(ldap_config, username, external_authentication) 
		ldap.bind_as(
			:base => ldap_config["base_dn"],
			:filter => ldap_filter,
			:password => password
		)
	end

	def self.init_ldap(ldap_config)
		options = {
			:host => ldap_config['host'],
			:port => ldap_config['port'],
			:encryption => (ldap_config['tls'] ? :simple_tls : nil),
			:auth => { 
				:method => ldap_config['auth']['method'],
				:username => ldap_config['auth']['bind_dn'],
				:password => ldap_config['auth']['bind_pw']
			}
		}
		Net::LDAP.new options
	end

end
