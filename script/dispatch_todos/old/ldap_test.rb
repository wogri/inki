#!/usr/bin/ruby

require 'ldap_lib.rb'
require 'yaml'

conn = ldap_connect('localhost', 'cn=admin,dc=wogri,dc=at', 'cR5sl2t')
puts conn.inspect

object = [
  LDAP.mod(LDAP::LDAP_MOD_ADD,'objectclass',['top','organizationalUnit']),
	LDAP.mod(LDAP::LDAP_MOD_ADD,'ou',['test_entry2']),
	#'objectclass' => ['top', 'organizationalUnit'],
	#'ou' => ['test_entry2'],
]


# ldap_add(conn, 'ou=test_entry2, dc=kt-net, dc=at', object)

base = 'ou=users,dc=kt-net,dc=at'
scope = LDAP::LDAP_SCOPE_SUBTREE
filter = '(uid=woe_guex)'
# attrs = ['mailAlias', 'cn']

found = false
conn.search(base, scope, filter) do |entry|
	found = true
end

p found.inspect
