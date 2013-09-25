class DispatchMailer < ActionMailer::Base
  default from: "Inki Database Dispatcher <noreply@inki.io>"

	def error_mail(mail, body)
		@body = body
		@mail = mail
		logger.info("sending out mail to #{@mail}")
		mail(:to => @mail, :subject => t(:dispatch_errors))
	end
end
