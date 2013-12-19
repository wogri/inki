class User < ActiveRecord::Base

	sort_by :username, "ASC"
	attr_accessor :dispatch_log
  belongs_to :usergroup
	index_order :username, :name, :mailaddress, :usergroup
	attribute_order :username, :password, :name, :mailaddress, :usergroup, :created_at
	attribute_properties :password => :password 
	has_icon "icon-user"
	read_only :username
	validates :password, :username, :name, :mailaddress, :usergroup_id, :presence => true
  validates :username, :uniqueness => true
	hide_json_attributes :password, :mailaddress
	hide_on_create :username
	is_expirable
	is_versioned
	can_be_dispatched
  paginates_per 10

  # the convention is to present the password as 'xxxxxxxxxx', and only if it was changed it will be overwritten.
	# this could also be done with a before_safe operation. 
  def password=(password)
    return if password == 'xxxxxxxxxxx'
    require 'digest/md5'
    password = Digest::MD5.hexdigest(password)
    write_attribute(:password, password)
  end

	def password
		'xxxxxxxxxxx'
	end

	def password_hash
		read_attribute(:password)
	end
	
	def self.authenticate(username, password)
    require 'digest/md5'
    digest = Digest::MD5.hexdigest(password)
    user = User.where(:username => username, :password => digest).first
		return user if user 
		# use ldap authentication if the local user can't be found
		Ldap.authenticate(username, password)
	end

	# adds a dispatch-log entry for a specific user
	def add_dispatch_log(text)
		if not self.dispatch_log
			self.dispatch_log = ''
		end
		self.dispatch_log += text
	end
	
	#def as_json(options={})
     #options[:except] ||= [:password]
     #super(options)
  #end

	private

end
