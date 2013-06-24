class Auth < ActiveRecord::Base
	
	def self.authenticate(username, password, auth_source)
    require 'digest/md5'
		digest = Digest::MD5.hexdigest(password)
		logger.info("AUTH SOURCE IS: #{auth_source}")
		if auth_source == "yaml" 
			# load YAML File	
			YamlUser.authenticate(username, digest)
		elsif auth_source == "database"
			User.where(:username => username, :password => digest).first
		elsif auth_source == "ldap"
			# use ldap authentication if the local user can't be found
			Ldap.authenticate(username, password)
		else
			logger.error("#{auth_source} is not a valid authentication method. Please check your inki configuration file. ")
			nil
		end
	end

end
