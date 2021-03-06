class DispatchQueue # < ActiveRecord::Base

	# add todos for a job
	def add(todos)
		if not defined? @todos
			@todos = []
		end
		@todos += todos
	end

	def size
		if not @todos
			return 0
		end
		@todos.size
	end

	# sends out an e-mail about failed todos. groups jobs to owners, so each owner gets only one e-mail with all the failed jobs. 
	def mail_failed_todo(todo)
		users = {}
		log = []
		todo.failed_jobs.each do |failed_job|
			mail = []
			mail << "#{$config[:global][:base_url]}/dispatch_todos/#{failed_job.id}"
			mail << failed_job.log
			mail = mail.join("\n") + "\n\n"
			log << mail
			if job = failed_job.dispatch_job and owner_id = job.owner_mail_address
				if not users[owner_id]
					users[owner_id] = mail
				else
					users[owner_id] += mail
				end
			else
				error("can not send out e-mail. ")
			end
		end
		begin
			users.each do |mail, log|
				DispatchMailer.error_mail(mail, log).deliver
			end
		rescue
			if rescue_mail_address = Rails.configuration.inki.dispatch_mail_address
				DispatchMailer.error_mail(rescue_mail_address, log.join("\n")).deliver
			end
		end
	end

	# fork off and run jobs
	def run!
		all_todos = flatten_todos(@todos)
		all_todos.each do |todo|
			todo.run!
		end

		while all_todos.size > 0
			done_todos = []
			all_todos.each_with_index do |todo, index|
				#debug("is my thread still alive? #{todo.thread.alive?}")
				if todo.tick! < 0 
					debug("todo time of todo #{todo.todo} is up, I have to kill the thread now.", 1)
					Process.kill("TERM", todo.thread.pid)
					log = "Timeout, killed. This todo took too long to complete."
					todo.get_jobs.each do |job|
						todo = job.todos.create(:todo => todo.todo, :done => false, :host => todo.host, :log => log)
						todo.failed = true
						todo.add_failed_job(todo)
						job.unlock!
					end
					done_todos.push(index)
				elsif not todo.thread.alive?
					todo.thread.join
					debug("return-status is: #{todo.return_status}")
					done_todos.push(index)
				end
				if todo.failed
					self.mail_failed_todo(todo)
					todo.failed_jobs.each do |failed_job|
						# TODO: insert code that handles optimistic locking
						dispatch_job = failed_job.dispatch_job
						done = false
						while not done 
							begin
								dispatch_job.reload
								dispatch_job.increase_retries!
								dispatch_job.update_retry_time!
								dispatch_job.save
								done = true
							rescue StandardError => e
								debug("Saving dispatch job information failed due to optimistic locking issues: #{e}. will retry in around 10 seconds")
								sleep rand(10)
							end
						end
					end
				end
			end
			sleep 1
			# delete the todos that have been done so that the loop isn't traversed anymore.
			done_todos.sort.reverse.each do |d|
				all_todos.delete_at(d)
			end
		end
	end

	# this function finds jobs that add up to the same todo and flattens them into one todo-object with multiple jobs.
	def flatten_todos(my_todos)
		return [] if not my_todos or my_todos.size == 0
		todos = []
		my_todos.each do |todo|
			match = false
			todos.each do |existing_todo|
				if existing_todo.compare(todo)
					existing_todo.add_jobs(todo.get_jobs)
					match = true
				end
			end
			if not match
				todos.push(todo)
			end
		end
		todos
	end

	private

end
