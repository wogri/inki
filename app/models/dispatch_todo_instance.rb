class DispatchTodoInstance < ActiveRecord::Base

	 attr_accessor :instances, :options
	 
	def initialize
	 	self.instances = []
		parse_options
	end

	# a command looks like this ["#{Rails.root}/script/dispatch_todos/#{self.todo}", '-models', model_description, '-host', self.host, '-options', "'#{self.options.to_yaml}'"]
	# the option-parser has to take care about this. 
	def parse_options
		require 'optparse'
		o = {}
		opts = OptionParser.new do |opts|
			opts.banner = "Usage: #{$0} <options>"
			opts.on("-m", "--models MODEL_DESCRIPTION", "Run this todo for those models in MODEL_DESCRIPTION (model-table-name, id, modify-operation)", "e.g. -models user_accounts:16:update,user_mail_addresses:23:delete") do |v| 
				build_models(v)
			end 
			opts.on("-t", "--host HOST", "HOST for this todo: e. g. -host ldap.inki-db.com") do |v| 
				o[:host] = v
			end 
			opts.on("-o", "--options YAML", "Options for this todo in YAML: e. g. --options '--- run_after_each_device: sudo /sbin/restart'") do |v| 
				o[:options] = YAML.load(v.sub(/^'/, '').sub(/'$/, ''))
			end
			opts.on("-h", "--help", "Get help") do |v| 
				puts opts
				exit 0
			end 
		end.parse!
		self.options = o
	end

	# builds models for the given options 
	def build_models(options)
		models = options.split(/,/)
		models.each do |model|
			table, id, operation, dispatch_id = model.split(/:/)
			if operation != "destroy" 
				instance = table.classify.constantize.find(id)
			elsif operation == "destroy" 
				dispatch_job = DispatchJob.find(dispatch_id)
				begin
					instance = YAML::load(dispatch_job.model_description)
				rescue StandardError => e
					logger.error(e.to_s)
				end
			else
				logger.warn("could not add dispatch-job with ID #{dispatch_id} to job queue. Please inspect.")
			end
			instance._operation = operation 
			instance._dispatch_id = dispatch_id
			instances << instance
		end
	end

	def jobs 
		self.instances
	end

	def emit_log(instance, log)
		puts "#{instance._dispatch_id}||#{log}"
	end

	def success!(instance)
		emit_log(instance, "__OK")
	end

end
