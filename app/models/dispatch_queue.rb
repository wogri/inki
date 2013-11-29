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
		todo.failed_jobs.each do |failed_job|
			mail = []
			mail << "#{$config[:global][:base_url]}/dispatch_todos/#{failed_job.id}"
			mail << failed_job.log
			mail = mail.join("\n") + "\n\n"
			if failed_job.dispatch_job and owner_id = failed_job.dispatch_job._owner_id
				if not users[owner_id]
					users[owner_id] = mail
				else
					users[owner_id] += mail
				end
			else
				error("can not send out e-mail. ")
			end
		end
		users.each do |mail, log|
			DispatchMailer.error_mail(mail, log).deliver
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
					todo.add_fail_log("Timeout, killed. This todo took too long to complete.")
					todo.get_jobs.each do |job|
						job.unlock!
					end
					todo.failed = true
					todo.failed_jobs = todo.get_jobs
					done_todos.push(index)
				elsif not todo.thread.alive?
					todo.thread.join
					debug("return-status is: #{todo.return_status}")
					done_todos.push(index)
				end
				if todo.failed
					self.mail_failed_todo(todo)
					todo.failed_jobs.each do |failed_job|
						failed_job.dispatch_job.increase_retries!
						failed_job.dispatch_job.update_retry_time!
						failed_job.dispatch_job.save
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
