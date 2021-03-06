class DispatchJob < ActiveRecord::Base

	attr_accessor :success, :log

	# returns all dispatches that are not done yet
	scope :undone_dispatches, lambda { 
		where(
			:retry_at => (Time.now - 1.year)..(Time.now), 
			:done => false, 
			:locked => false
		).order(:id)
	}
	# returns all dispatches that are not finished yet
	scope :unfinished, lambda { 
		where(
			:done => false
		)
	}

	# returns all objects that are locked and have not been unlocked for 2 days - these are zombies
	scope :zombie_locks, lambda { where(:locked_at => (Time.now - 1.year)..(Time.now - 2.days), :locked => true, :done => false) }
	scope :locked, lambda { where(:locked => true, :done => false) }
	attribute_order :created_at, :inki_model_name, :model_id, :locked, :done, :locked_at, :model_description, :model_operation, :retries, :retry_at, :owner_mail_address, :current_todos
	index_order :created_at, :inki_model_name, :model_id, :locked, :done, :locked_at, :model_operation, :retries
	has_many :dispatch_todos, :dependent => :destroy
	sort_by :created_at, "DESC"

	read_only :locked_at, :model_description, :model_id, :inki_model_name, :model_operation

	# lock the dispatch_job and set the locked_at date, saves the object
  # does optimistic locking
	def lock!(options = {sleeptime: 1})
		self.reload
		self.locked = true
    if options[:sleeptime] > 8
      raise "Optimistic locking failed"
    end
		self.locked_at = Time.now
		begin
		  self.save
		rescue ActiveRecord::StaleObjectError
			error("seems like the job with the id #{self.id} has been modified by somebody else, will retry to re-lock the job in #{options[:sleeptime] * 2} seconds.")
			sleep options[:sleeptime]
			self.lock!(sleeptime: options[:sleeptime] * 2)
		end

	end

	# unlock and save the object.
	def unlock!(options = {sleeptime: 1})
		self.reload
		self.current_todos -= 1
		if self.current_todos < 1 or options[:force]
			# there exists the special case, where current_todos could become minus one (that is, when all todos are done and 0 todos are due, then this will be decreased to below zero. that's why we set it to zero here, for a 'better optic' 
			self.current_todos = 0
			self.locked = false
		end
    if options[:sleeptime] > 8
      raise "Optimistic locking failed"
    end
		begin
			self.save
		# retry this operation if somebody updated the data in the mean time!
		rescue ActiveRecord::StaleObjectError
			error("seems like the job with the id #{self.id} has been modified by somebody else, will retry to unlock the job in #{options[:sleeptime]*2} seconds.")
			sleep options[:sleeptime]
			self.unlock!(sleeptime: options[:sleeptime] * 2)
		end
	end

	# sets done to true and saves the object
	def done!
		self.done = true
		self.save
	end

	# an alias for dispatch_todos to save some typing
	def todos
		self.dispatch_todos
	end

	# stores the information that a todo has been executed successfully
	def completed_todo(host, todo, log)
		self.todos.create(:host => host, :todo => todo, :log => log, :done => true)
	end

	def update_retry_time!
		self.retry_at = Time.now + 60 * self.retries + 4 ** self.retries
	end

	def increase_retries!
		if not self.retries
			self.retries = 1
		else
			self.retries += 1
		end	
	end

	# checks if a todo has already been done for a host
	def find_undone_hosts_for_todo(todo, hosts)
		done_todos = self.todos.where(:todo => todo, :done => true)
		done_hosts = []
		done_hosts = done_todos.map do |done_todo|
			done_todo.host
		end
		hosts - done_hosts
	end

# finds todos
#  :dispatches:
#    ldap.wogri.at:
#      :ldap:
#        :lifetime: 60 # can take up to 30 seconds
#        :interested_in_objects: # is only executed when the following objects are dispatched
#        - user_accounts
#        - user_mail_addresses
#        - user_rights
#        - user_homepages
#        - user_spamassassin_settings
#        :server: ldap.wogri.at
#        :bind_dn: cn=admin,dc=wogri,dc=at
#        :bind_pw: xxx
#        :mode: :user
	def find_todos(config)
		my_todos = []
		begin
			config[:dispatches].each do |host, todos|		
				todos.each do |todo, options|
					if options[:interested_in_objects].member?(self.inki_model_name) and not self.todos.where(:todo => todo, :host => host, :done => true).first
						new_todo = DispatchTodo.new
						new_todo.host = host
						new_todo.todo = todo
						new_todo.options = options
						new_todo.add_job(self)
						my_todos.push(new_todo)
					else
						debug "found completed todo #{todo} for job-id #{self.id}, will not re-do the todo."
					end
				end
			end
		rescue StandardError => e
			error "Very bad: find_todos crashed, please check your dispatch.yml, the error might be in there: #{e}"
			error e.backtrace.join("\n")
			return nil
		end
		my_todos
	end
	
	def add_log(log_entry)
		if not self.log
			self.log = ""
		end
		self.log += log_entry
	end

end
