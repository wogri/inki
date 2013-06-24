require 'ldap'
def ldap_connect(host, user, password)
	conn = LDAP::Conn.new(host)
	if conn
		conn.set_option(LDAP::LDAP_OPT_PROTOCOL_VERSION, 3)
		conn.bind(user, password, LDAP::LDAP_AUTH_SIMPLE)
	end
	conn
end

def ldap_disconnect(conn)
	conn.unbind
end

def ldap_add(conn, dn, object)
	begin
		debug("adding '#{dn}'")
		conn.add(dn, object)
	rescue LDAP::ResultError
		conn.perror("add")
		return nil
	end
	return true
end

def ldap_modify(conn, dn, object)
	begin
		debug("modifying #{dn}")
		conn.modify(dn, object)
	rescue LDAP::ResultError
		conn.perror("modify")
		return nil
	end
	return true
end

def ldap_delete(conn, dn)
	begin
		debug("deleting #{dn}")
		conn.delete(dn)
	rescue LDAP::ResultError
		conn.perror("delete")
		return nil
	end
	return true
end

def ldap_search(conn, filter, base = 'dc=kt-net,dc=at', scope = LDAP::LDAP_SCOPE_SUBTREE) 
	entries = []
	# there is a weird bug - if  I added the entries to a hash it would bork me off (stack too deep error). 
	begin
		conn.search(base, scope, filter) do |entry|
			# That's why I simply add the DN to the resulting array. 
			dn = entry.dn
			entries.push dn
		end
	rescue
		entries = []
	end
	if entries.size == 0
		return nil
	else 
		return entries
	end
end
