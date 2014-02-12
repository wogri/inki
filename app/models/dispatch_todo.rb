class DispatchTodo < ActiveRecord::Base

	attr_accessor :options, :time_to_live, :thread, :stdout, :stdin, :log_output, :return_status, :failed, :failed_jobs

	belongs_to :dispatch_job
	attribute_order :created_at, :host, :todo, :log, :done
	sort_by :id, "DESC"

	# returns true if the two objects have the same host, options and todo-name
	def compare(comparator)
		self.host == comparator.host and self.options == comparator.options and self.todo == comparator.todo
	end

	def add_job(job)
		if not defined? @jobs
			@jobs = []
		end
		@jobs.push(job.clone)
	end

	def add_jobs(jobs)
		@jobs += jobs
	end

	def get_jobs
		@jobs
	end

	def build_command
		model_description = self.get_jobs.map do |job|
			"#{job.model_name}:#{job.model_id}:#{job.model_operation}:#{job.id}"
		end.join ","
		executable = todo.to_s.gsub(/\.\d+$/, '') # the todo can be an alias, any .<NUMBER> will be removed.
		command = ["#{Rails.root}/script/dispatch_todos/#{executable}", '--models', model_description, '--host', self.host, '--options', "'#{self.options.to_yaml}'"]
		debug("running command: #{command.join ' '}", 1)
		command
	end

	def handle_error(e)
		error_log = [e.to_s] + e.backtrace
		error(error_log.join("\n"))
		self.log_output = error_log
		check_and_save_status
		job.unlock!
	end

	# cleans up stuff regarding the todo and jobs
	def cleanup!
		#self.get_jobs.each do |job|
			#job.unlock!
		#end
	end

	# runs the todo, starts a thread, iop.opens stuff, waits until the popen program is done, and sets logs and return status
	def run!
		begin
			self.time_to_live = self.options[:lifetime] || 60
			command = build_command
			self.stdin, self.stdout, self.thread = Open3.popen2e(*command)
		rescue StandardError => e
			handle_error(e)
		end
	end
	
	def tick!
		check! # checks on the thread (if it is one or not)
		# a second has passed, the todo has to decremt it's time to live
		self.time_to_live -= 1
	end

	# checks if the thread is finished or not and saves thread-output if there is any
	def check!
		# this condition is only met if the thread is done (status == false)
		# puts "todo status is: #{self.thread.status.inspect}."
		puts "todo ##{self.todo} status is: #{self.thread.status.inspect}."
		if not self.thread.status
			self.log_output = self.stdout.readlines
			self.return_status = self.thread.value.exitstatus
			self.stdout.close 
			self.stdin.close
			check_and_save_status
		end
	end

	# checks the log output and the return status of popen per assigned job 
	# a job needs to return model_name:model_id:model_operation __OK to the pipe, then we know it was successful.
	def check_and_save_status
		job_hash = build_job_hash
		self.log_output.each do |log|
			dispatch_id = nil
			log_entry = nil
			job = nil
			if log =~ /||/
				job_identifier, log_entry = log.split(/\|\|/, 2)
				job = job_hash[job_identifier.to_i]
			end
			# the log-entry wasn't specific for a certain job but for all jobs
			if not job
				job_hash.each do |dummy, job|
					debug("adding unidentified log '#{log.chomp}' to job-id #{job.id}")
					job.add_log(log.chomp + "\n")
				end
				if log =~ /^__OK/ and self.return_status == 0
					job_hash.each do |dummy, job|
						job.success = true 
					end
				end
				next
			end
			if log_entry =~ /^__OK/ and self.return_status == 0
				job.success = true 
			end
			debug("adding #{log.chomp} to directly passed job-id #{job.id}")
			job.add_log(log_entry.chomp + "\n")
		end
		job_hash.each do |dummy, job|
			# if a job has all of the todos marked as successful, the job is eventually (on the next dispatch-run) marked as done. 
			job.add_log("Exit-Status: #{self.return_status}")
			my_todo = job.todos.create(:todo => self.todo, :done => job.success, :host => self.host, :log => job.log)
			if not job.success 
				self.failed = true
				self.add_failed_job(my_todo)
			end
			job.unlock!
		end
	end

	def add_failed_job(job)
		if not self.failed_jobs
			self.failed_jobs = []
		end
		self.failed_jobs.push(job)
	end

	# builds a hash to look up jobs by model-name and model-id
	def build_job_hash
		job_hash = {}
		self.get_jobs.each do |job|
			job_hash[job.id] = job
		end
		job_hash
	end

	# adds a log to all jobs - something failed (timeout) from the "outside"
	def add_fail_log(log)
		self.get_jobs.each do |job|
			job.add_log(log)
		end
	end

end
