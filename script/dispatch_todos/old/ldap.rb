class Ldap < Dispatcher

	require 'methods/ldap_lib.rb'
  require 'methods/build_user.rb'
  # attr_accessor :queue, :dispatcher, :writer, :current_method

  def run!
    debug "queue is: #{queue.to_yaml}" 
    debug "dispatcher is: #{dispatcher.to_yaml}"
    debug "current_method is: #{current_method.to_yaml}"
    dbh = connect_to_database
		ldap_connection = ldap_connect(current_config[:server], current_config[:bind_dn], current_config[:bind_pw])
    current_method[:jobs].each do |job|
			debug("looking for a table called #{job["object_name"]} / #{job[:dispatch_action]}...")
      if job[:dispatch_action] == :delete and (job["object_name"] == "user_accounts" or job["object_name"] == "domains")
        debug("delete statement triggered, deleting the object from the database")
				ldap_remove(dbh, job["object_id"], ldap_connection, job)
      else
				object = nil
				if current_config[:mode] == :user
					object = build_user_hash(dbh, job["object_id"], job["object_name"])
				end
				# this might be a delete-situation where the parent doesn't exist anymore, this simply needs to return. 
				if object == nil
					debug "nothing found. damn it"
    			disconnect_from_database(dbh)
					return
				end
				ldap_remove(dbh, object[:data]["id"], ldap_connection, job)
				ldap_update(object, ldap_connection, job, dbh)
      end
    end
    disconnect_from_database(dbh)
  end

	# this function deletes entries in the ldap-database - recursively!
	def ldap_remove(dbh, id, ldap_connection, job)
		dn = nil
		if current_config[:mode] == :user
			sql = "SELECT * from user_accounts where id = #{id}"
		elsif current_config[:mode] == :domain
			sql = "SELECT * from domains where id = #{id}"
		end
		object = execute_sql_query(dbh, sql).first
		# DNS = DN's (nicht Dynamic Name Service)
		dns = []
		if current_config[:mode] == :user
			dn = "uid=#{object["username"]},ou=People,o=wogriAtUsers,dc=wogri,dc=at"
			# find all children of this entry in the ldap-database
			dns = ldap_search(ldap_connection, "objectClass=*", dn)
		end

		if not dns
			return nil
		end
		dns.reverse.each do |dn|
			# now execute the ldap query to delete the user from the ldap-database
			result = ldap_delete(ldap_connection, dn)
			if not result
				debug "error while deleting dn=#{dn}"
				job_error(job, ldap_connection.err2string(ldap_connection.err))
			end
		end
	end

	def ldap_update(object, ldap_connection, job, dbh)
		# query the ldap server to see if we either need to create or update the user account
		search_result = nil
		if current_config[:mode] == :user
			common_name = object[:data]["username"]
			search_result = ldap_search(ldap_connection, "uid=#{common_name}", 'ou=People,o=wogriAtUsers,dc=wogri,dc=at')
		elsif current_config[:mode] == :domain
			# common_name = object[:data]["name"]
			# debug "calling get_domain_dn for ldapupdate"
			# dn = get_domain_dn(object[:data], dbh)
			# search_result = ldap_search(ldap_connection, "objectClass=*", dn)
			# nothing to do here :)
		end
		action = LDAP::LDAP_MOD_REPLACE
		result = nil
		if not search_result or current_config[:mode] == :domain
			action = LDAP::LDAP_MOD_ADD 
			ldap_objects = make_ldap_objects(object, action, dbh)
			# execute the ldap query to insert the user into the ldap-database
			ldap_objects.each do |object|
				result = ldap_add(ldap_connection, object[:dn], object[:object])
				if not result
					debug "no result for #{object[:dn]}, borking..."
					job_error(job, ldap_connection.err2string(ldap_connection.err))
				end
			end
		else
			ldap_objects = make_ldap_objects(object, action, dbh)
			# execute the ldap query to modify the user in the ldap-database
			ldap_objects.each do |object|
				result = ldap_modify(ldap_connection, object[:dn], object[:object])
				if not result
					job_error(job, ldap_connection.err2string(ldap_connection.err))
				end
			end
		end
	end

	# make an ldap conforming data structure
	def make_ldap_objects(object, action, dbh)
		debug(object.to_yaml)
		objects = []
		if current_config[:mode] == :user
			web_settings = false
			# the map converts the hash-elements to an ldap-element. 
			map = {
				"objectClass" => ['account', 'wogriAccount', 'posixAccount', 'shadowAccount', 'top'],
				"cn" => [object[:data]["name"]], 
				"gidNumber" => ["100"], 
				"homeDirectory" => [object[:data]["home_directory"]],
				"uid" => [object[:data]["username"]], 
				"uidNumber" => [object[:data]["user_id"].to_s],
				"loginShell" => [object[:data]["login_shell"]],
				"wogriService" => object["user_rights"][:data].uniq,
				"userPassword" => [object[:data]["sha_hash"]],
				"gecos" => [object[:data]["name"]],
				"jabberUID" => [object[:data]["jabber_uid"]],
				"contactMailAddress" => [object[:data]["contact_mail_address"]],
			}
			if object["user_spamassassin_settings"][:data].size > 0 and object["user_rights"][:data].member? "mail"
				map["spamassassin"] = get_spamassassin_attributes(object)
				map["spamdrop"] = [object[:data]["spamassassin_drop_score"]]
			end
			if object["user_mail_addresses"][:data].size > 0 and object["user_rights"][:data].member? "mail"
				map["eMailAlias"] = object["user_mail_addresses"][:data]
				map["vacationFrom"] = [object[:data]["vacation_from_integer"]]
				map["vacationUntil"] = [object[:data]["vacation_until_integer"]]
				map["vacationMessage"] = [object[:data]["vacation_message"]]
			end
			if object["user_homepages"][:data].size > 0 and object["user_rights"][:data].member? "ftp"
				map["ftpQuota"] = ["false,soft,#{object[:data]["ftp_quota"].to_i * 1000000},-1,-1,-1,-1,-1"] 
				map["homepages"] = object["user_homepages"][:data]
			end
			ldap_object = make_ldap_map(map, action)
			objects.push({:dn => "uid=#{object[:data]["username"]},ou=People,o=wogriAtUsers,dc=wogri,dc=at", :object => ldap_object})
		end
		objects
	end

	# build an ldap-corresponding map
	def make_ldap_map(map, action)
		object = []
		map.each do |key,value|
			debug("key: #{key.inspect} / value: #{value.inspect}")
			if value.size == 1 and value.first == nil or value.first == ''
				value = []
			end
			if value.size > 0
				object.push(LDAP.mod(action, key, value)) 
			end
		end
		object
	end

	# build ldap-conform spamassassin-attributes
	def get_spamassassin_attributes(user) 
		attribs = user["user_spamassassin_settings"][:data]
		attribs.push "required_hits #{user[:data]["spamassassin_required_score"]}"
		attribs.uniq!
		attribs
	end

	def get_domain_dn(domain, dbh)
		sql = "SELECT * FROM current_domain_mail_settings where domain_reference_id = #{domain["reference_id"]}"
		domain_mail_setting = execute_sql_query(dbh, sql).first
		if domain_mail_setting["local_domain"] == true
			return "ou=#{domain["name"]},ou=localDomains,dc=kt-net,dc=at"
		elsif domain_mail_setting["forward_mail_server"] =~ /^.+$/
			return "ou=#{domain["name"]},ou=relayDomains,dc=kt-net,dc=at"
		elsif domain_mail_setting["forward_email_address"] =~ /^.+$/
			return "ou=#{domain["name"]},ou=domainToExternalMail,dc=kt-net,dc=at"
		else
			return nil
		end
	end
	
end
