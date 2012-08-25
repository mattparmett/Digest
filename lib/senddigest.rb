#Script to be run in cron on heroku and send daily email digest
#This shouldn't have to be touched by the user -- all the action happens in the plugins

require 'rubygems'
require 'date'
require 'pony'
require 'rss'
require 'open-uri'
require 'mechanize'
require 'sanitize'
require 'yaml'
require 'ostruct'
require File.expand_path(File.dirname(__FILE__)) + '/plugin_manager.rb'
require 'erb'
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

###
#Constants
###

GMAIL_USER = ENV["gmail_username"]
GMAIL_PASS = ENV["gmail_password"]
EMAIL_ADDR = ENV["email"]
CFG_FILE = File.expand_path(File.dirname(__FILE__)) + '/../config.yml'
ee_url = "http://evening-edition.com/"

###
#Plugins
###
$APP_CONFIG = OpenStruct.new(YAML.load(ERB.new(File.read(CFG_FILE)).result))
@plugin_manager = PluginManager.new()


###
#Class Overrides
#(Because I'm lazy...)
###

class Date
	def components()
		date = self.to_s.split("-")
		year = date[0]
		month = date[1]
		day = date[2]
		return {'year' => year, 'month' => month, 'day' => day}
	end
	
	#...why is this not included already?
	def self.yesterday()
		Date.today - 1
	end
end

###
#Configure Email
###

#Date
today = Date.today.components()

#Email-related params
@to_email = EMAIL_ADDR
@from_email = EMAIL_ADDR
@email_subject = "Digest for #{today['month']}/#{today['day']}/#{today['year']}"
@gmail = {
	:host => 'smtp.gmail.com',
	:port => '587',
	:enable_starttls_auto => true,
    :user_name            => GMAIL_USER,
    :password             => GMAIL_PASS,
    :authentication       => :plain, # :plain, :login, :cram_md5, no auth by default
    :domain               => "localhost.localdomain" # the HELO domain provided by the client to the server
}

###
#Erb template
###
@template = %{
  <html>
    <head>
	<title></title>
	</head>
    <body>
		<h1><%= @email_subject %></h1>
		<% @plugin_manager.plugins.each do |plugin| %>
			<%= plugin.to_html() %>
		<% end %>
    </body>
  </html>
}.gsub(/^  /, '')

###
#Send digest email
###
body = ERB.new(@template)
email_body = Sanitize.clean(body.result, :elements => ['a', 'h1', 'h2', 'h3', 'p', 'ul', 'li'], :attributes => {'a' => ['href']}, :protocols => {'a' => {'href' => ['http', 'https', 'mailto']}})
Pony.mail({
	:to => @to_email,
	:sender => @from_email,
	:subject => @email_subject,
	:html_body => email_body,
	:via => :smtp,
	:via_options => {
		:address              => @gmail[:host],
		:port                 => @gmail[:port],
		:enable_starttls_auto => @gmail[:enable_starttls_auto],
		:user_name            => @gmail[:user_name],
		:password             => @gmail[:password],
		:authentication       => @gmail[:authentication], # :plain, :login, :cram_md5, no auth by default
		:domain               => @gmail[:domain] # the HELO domain provided by the client to the server
  }
 })