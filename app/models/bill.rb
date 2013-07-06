class Bill < ActiveRecord::Base
	sort_by :bill_id, "DESC"
	attribute_order :bill_id, :bill_date, :project, :bill_template, :payed, :comment
	index_order :bill_id, :bill_date, :project, :payed, :comment
	belongs_to :project
	belongs_to :bill_template
	validates_presence_of :bill_date, :bill_template
	has_many :time_elements, :dependent => :delete_all

	special_buttons :add_elements => {:description => :adds_bill_elements, :icon => "icons/linechart.png"}, 
		:pdf => {:description => :create_pdf, :icon => "icons/printer.png"}
	before_create :set_bill_id
	help :bill_id => :can_be_empty

	def set_bill_id
		self.bill_id = Bill.maximum("bill_id").to_i + 1
	end

	def to_pdf
		require 'erb'
		@bill = self
		bill = self
		@project = self.project
		@customer = @project.customer
		@time_elements = @bill.time_elements.order("time_start ASC")
		@hour_sum = 0
		@cost_sum = 0
		@time_elements.each do |t|
			@cost_sum += t.calculate_cost
			@hour_sum += t.duration_float
		end
		template = ERB.new(self.bill_template.template)
		directory = "#{Rails.root}/tmp/bill_downloads/"
		if not File.directory? directory
			Dir.mkdir(directory)
		end
		file = "#{directory}/#{self.bill_id}.tex"
		File.open(file, 'w') do |f|
			f.write(template.result(binding))
		end
		IO.popen("pdflatex -output-directory #{directory} #{file}") do |handle|
			pdflatex_output = handle.read
		end
		if $? == 0
			return 0
		else
			return pdflatex_output
		end
	end

end
