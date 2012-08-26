require 'rubygems'
require 'erb'
require 'pony'
require 'sanitize'
require File.expand_path(File.dirname(__FILE__)) + '/date.rb'
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

###
#DigestEmail Class
#Class that handles the creation and sending of the digest email
###

class DigestEmail
	attr_accessor :plugins, :template, :body, :subject
	
	#Initialize takes args:
		# plugins: array of plugin objects from PluginManager (e.g. plugin_manager_name.plugins)
		# gmail_account: hash of gmail account info for pony in the form of:
			# gmail = {
				# :host => 'smtp.gmail.com',
				# :port => '587',
				# :enable_starttls_auto => true,
				# :user_name            => GMAIL_USER,
				# :password             => GMAIL_PASS,
				# :authentication       => :plain, # :plain, :login, :cram_md5, no auth by default
				# :domain               => "localhost.localdomain" # the HELO domain provided by the client to the server
			# }
		# template: erb template; see below default template for reference
	def initialize(args)
		#Set indifferent access for args hash
		args.default_proc = proc do |h, k|
		   case k
			 when String then sym = k.to_sym; h[sym] if h.key?(sym)
			 when Symbol then str = k.to_s; h[str] if h.key?(str)
		   end
		end
		
		#Assign instance vars
		@plugins = args[:plugins]
		if args[:gmail_account]
			@gmail_account = args[:gmail_account]
		else
			raise "Error: Invalid Gmail account information specified."
		end
		
		#Assign template instance var, falling back to default
		#Users shouldn't need to touch or provide this, but are able to if they choose
		if args[:template]
			@template = args[:template]
		else
			#Erb template
			@template = %{
			  <html>
				<head>
				<title></title>
				</head>
				<body>
					<h1><%= "Digest for #{Date.today.components['month']}/#{Date.today.components['day']}/#{Date.today.components['year']}" %></h1>
					<% @plugins.each do |plugin| %>
						<%= plugin.to_html() %>
					<% end %>
				</body>
			  </html>
			}.gsub(/^  /, '')
		end
	end
	
	#Takes an erb template, runs it with local binding, and sanitizes it for the email body
	def construct_body(template = @template)
		@body = ERB.new(template).result(binding)
		allowed_elements = ['a', 'h1', 'h2', 'h3', 'p', 'ul', 'li']
		allowed_attributes = {'a' => ['href']}
		allowed_link_protocols = {'a' => {'href' => ['http', 'https', 'mailto']}}
		return Sanitize.clean(@body, :elements => allowed_elements, :attributes => allowed_attributes, :protocols => allowed_link_protocols)
	end
	
	#Fires off the digest email
	def send(to, from, subject = nil)
		#Set subject default value
		if subject.nil?
			#Date
			today = Date.today.components()
			#Construct subject line
			@subject = "Digest for #{today['month']}/#{today['day']}/#{today['year']}"
		else
			@subject = subject
		end
		
		@to = to
		@from = from
		
		#Check if body has been constructed
		#If not, we should construct it before sending
		self.construct_body() unless (defined? @body and !(@body.nil?))
		
		#Send digest email
		Pony.mail({
			:to => @to,
			:sender => @from,
			:subject => @subject,
			:html_body => @body,
			:via => :smtp,
			:via_options => {
				:address              => @gmail_account[:host],
				:port                 => @gmail_account[:port],
				:enable_starttls_auto => @gmail_account[:enable_starttls_auto],
				:user_name            => @gmail_account[:user_name],
				:password             => @gmail_account[:password],
				:authentication       => @gmail_account[:authentication], # :plain, :login, :cram_md5, no auth by default
				:domain               => @gmail_account[:domain] # the HELO domain provided by the client to the server
		  }
		 })
	end
end