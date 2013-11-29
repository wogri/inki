#!/usr/bin/ruby 

require 'syslog'
require 'optparse'
require 'open3'

Syslog.open('dispatcher')

# rails generate model dispatch_job model_name:string model_id:integer model_operation:string retries:integer locked:boolean locked_at:datetime done:boolean model_description:text 
# rails generate model dispatch_todo dispatch_job_id:integer todo:string host:string done:boolean log:text
# rails generate model dispatch_errors dispatch_job_id:integer host:string todo:string log:text

def debug(message = "", level = 5)
  if $config[:global][:verboselevel] and $config[:global][:verboselevel] >= level
    puts message 
		#logger.info(message)
    Syslog.info(message)
  end
end

def error(message = "")
  STDERR.print message + "\n"
  Syslog.err(message)
	#logger.error(message)
end


options = {}
opts = OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} <options>"
  opts.on("-d", "--daemon", "Run in background (default is to not detach from console)") do |v|
    options[:daemonize] = true
  end
  opts.on("-v LEVEL", "--verbose LEVEL", "Override verbosity level (ignore configuration file value)") do |v|
		options[:verboselevel] = v.to_i
  end
  opts.on("-h", "--help", "Get this help") do |v|
    puts opts
    exit 0
  end
end.parse!

puts("starting the inki-dispatcher")

if options[:daemonize]
  pid = fork
  # the parent has to die, the pid-varaible contains the process-id of the child
  exit if pid
  File.umask 0000
  STDIN.reopen "/dev/null"
  STDERR.reopen STDOUT
  STDOUT.reopen "/dev/null", "a"
end

# load the whole rails enviroment
require "#{File.dirname(__FILE__)}/../config/environment.rb"

CONFIG_FILE = "#{Rails.root}/config/dispatcher.yml"
$config = YAML.load(File.read(CONFIG_FILE))[Rails.env]

# read the config file 
if not File.exist?(CONFIG_FILE)
	error("no dispatch- config file: #{CONFIG_FILE}. Please create one by possibly copying the template-file (#{CONFIG_FILE}.template) to #{CONFIG_FILE}")
	return nil
end

$config[:global][:verboselevel] = options[:verboselevel] if options[:verboselevel]

# do this once after startup
locked_dispatch_jobs = DispatchJob.locked.each do |job|
	job.unlock!
end

# loop that thing forever
Thread.abort_on_exception = true # this is temporary until things have stabilized. If this is set, the main process will die if any thread raises an exception

threads = [] # a list of running threads - this is used to track threads and prevent memory leaks
counter = -1
while true do 
	counter += 1
	# refresh the config-file upon every dispatch-run
	# $config = YAML.load(File.read(CONFIG_FILE))[Rails.env]
	# delete all jobs that are done and older than a specific time-range according to the conifg-file) - but only after 1000 queue-checks have passed.
	if counter > 1000
		DispatchJob.where(:updated_at => (Time.now - 2.years)..(Time.now - $config[:global][:remove_done_jobs_after].days), :done => true).delete_all
		counter = 0
	end
# run a loop that checks the dispatches-table. Only check on the first N items 
	dispatch_jobs = DispatchJob.undone_dispatches.limit($config[:global][:concurrent_items])

# unlock dispatches that are locked for longer than 48 hours - they have failed somehow very badly
	if counter % 100 == 0 
		debug("checking on zombies")
		DispatchJob.zombie_locks.each do |d|
			error("DispatchJob ##{d.id} (#{d.model_name}/#{d.model_id}) has been locked for more than 48 hours. Something is wrong with them. I will unlock them now") 
			d.unlock!
		end
	end
	
	if counter % 10 == 0 
		# collects dead threads
		threads.each do |thread|
			if not thread.alive?
				thread.join
			end
		end
	end
	queue = DispatchQueue.new
	dispatch_jobs.each do |job|
		job.lock!
		todos = job.find_todos($config)
		job.current_todos = todos.size
		job.save
		# if there are no todos, set the dispatch-job-status to 'done' 
		if todos.size == 0
			debug("no more todos for job-id #{job.id}. setting it to done.")
			job.done!
			job.unlock!
		elsif todos == nil
			error("seems like find_todos crashed, leaving this job alone. you need to fix this error in order to make this todo work.")
		else
			debug("adding dispatch-job-id #{job.id}")
			queue.add(todos)
		end
	end
	if queue.size > 0
		t = Thread.new do 
			debug("starting queue run") 
			queue.run!
			ActiveRecord::Base.clear_active_connections!
		end
		threads.push(t)
		#pid = fork
		#if pid # parent branch
		#	Process.detach(pid)
		#else # child branch
		#	exit 0
		#end
	end
	debug("sleeping for #{$config[:global][:sleepinterval]} seconds...", 5)
	sleep $config[:global][:sleepinterval]
end
