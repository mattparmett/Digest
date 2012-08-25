#Script to be run in cron on heroku and send daily email digest
#Needs to read in several feeds and create and send an email containing top stories

require 'rubygems'
require 'date'
require 'pony'
require 'rss'
require 'open-uri'
require 'mechanize'
require 'sanitize'
require 'erb'
#Require all modules:
Dir[File.dirname(__FILE__) + '/modules/*.rb'].each {|file| require file }
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

###
#Constants
###

GMAIL_USER = ENV["gmail_username"]
GMAIL_PASS = ENV["gmail_password"]
EMAIL_ADDR = ENV["email"]
ee_url = "http://evening-edition.com/"

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
#Executed Code
###

#Run plugins
@nyt_stories = DigestRSS.new("NYT", "http://feeds.nytimes.com/nyt/rss/HomePage", false, 5).to_html()
@nyy_score = DigestBaseballScore.new("Yankees", (Date.yesterday)).to_html()
@nyy_stories = DigestRSS.new("", "http://mlb.mlb.com/partnerxml/gen/news/rss/nyy.xml", false, 3).to_html('sports')
@hn_stories = DigestRSS.new("HN", "http://feeds.feedburner.com/newsyc100", true, 5).to_html()
@wsj_stories = DigestRSS.new("WSJ", "http://online.wsj.com/xml/rss/3_7011.xml", false, 5).to_html()
@ee_stories = DigestEveningEdition.new(ee_url).to_html()

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
		<%= @nyt_stories %>
		<%= @wsj_stories %>
		<%= @hn_stories %>
		<%= @nyy_score %>
		<%= @nyy_stories %>
		<%= @ee_stories %>
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