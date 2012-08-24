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
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

###
#Constants
###
CONFIG = 'senddigest.cfg'
GMAIL_USER = ENV["gmail_username"]
GMAIL_PASS = ENV["gmail_password"]
EMAIL_ADDR = ENV["email"]

###
#Methods
###
def get_rss_items(feed_url, num_items = 0)
	rss_content = ""
	open(feed_url) { |f| rss_content = f.read }
	rss = RSS::Parser.parse(rss_content, false)
	return rss.items[0...num_items] unless num_items == 0
	return rss.items
end

def get_todays_date()
	time = Time.new
	
	#Get correctly formatted month string
	if time.month < 10
		month_string = "0" + time.month.to_s
	else
		month_string = time.month.to_s
	end
	
	#Get correctly formatted day string
	if time.day < 10
		day_string = "0" + time.day.to_s
	else
		day_string = time.day.to_s
	end
	
	#Combine into one super date string
	date_string = month_string + "/" + day_string + "/" + time.year.to_s
	
	return date_string
end

def hn_stories(num_stories = 5)
	#Top 5 hacker news stories
	#Feed contains top 5 hn stories with 100+ points
	hn_feed_url = 'http://feeds.feedburner.com/newsyc100'
	rss_items = get_rss_items(hn_feed_url)
	
	#Make sure the stories are fresh for today (aka posted yesterday)
	today_stories = []
	rss_items.each do |story|
		#Date format: Thu, 16 Aug 2012 12:30:02 -0400
		s_date = story.date.to_s.split(" ")
		item_date = Date.new(s_date[3].to_i, Date::ABBR_MONTHNAMES.index(s_date[2]), s_date[1].to_i)
		#Get yesterdays date
		y = (Date.today - 1)
		today_stories << story if item_date == y
		return today_stories if today_stories.length == num_stories
	end
	return today_stories
end

def wsj_stories(num_stories = 5)
	#Top 5 WSJ US Homepage headlines via rss
	wsj_feed_url = "http://online.wsj.com/xml/rss/3_7011.xml"
	return get_rss_items(wsj_feed_url, num_stories)
end

def evening_edition_stories()
	#Evening edition news stories
	#Gonna have to page scrape this one
	ee_url = 'http://evening-edition.com'
	a = Mechanize.new()
	a.get(ee_url)
	story_titles_html = a.page.parser.xpath('/html/body/div[@class = "wrapper clearfix"]/section[@id = "news"]/div/article/h2')
	story_bodies_html = a.page.parser.xpath('/html/body/div[@class = "wrapper clearfix"]/section[@id = "news"]/div/article/p')
	ee_stories = {}
	(0..5).each do |i|
		story_title = story_titles_html[i].to_s.gsub("<h2>" , "").gsub("</h2>" , "")
		story_body = story_bodies_html[i].to_s.gsub("<p>" , "").gsub("</p>" , "")
		ee_stories[story_title] = story_body
	end
	return ee_stories
end

#Get yankees score from a certain day's game, via usatoday
def get_nyy_score(year, month, day)
	#Construct usatoday mlb url for the specified day's scores
	usa_url = "http://content.usatoday.com/sportsdata/scores/mlb/#{year}/#{month}/#{day}"

	#Navigate to main usatoday mlb page
	a = Mechanize.new()
	a.get(usa_url)

	#Get link for yesterday's yankees game
	usa_page_links = a.page.parser.xpath('//a').map {|a| a['href']}
	game_link = ""
	usa_page_links.each {|a| game_link = a if a.include? "Yankees" and !(a.include? "schedule") and !(a.include? "game-story") }
	
	#If there is no yankees link found, there was no yankee game that day. Return empty array.
	if game_link == ""
		return []
	end
	
	#Get team names and scores for yesterday's yankees game
	a.get(game_link)
	team_names = Sanitize.clean(a.page.parser.xpath('//table[@class = "scorebox"]/tr/td[@class = "l"]').to_s).split("\n")
	team_scores = Sanitize.clean(a.page.parser.xpath('//table[@class = "scorebox"]/tr/td[@class = "c team-score"]').to_s).split("\n")
	
	#Determine if yankees won
	win = false
	team_names.each_index do |i|
		if team_names[i] == "Yankees"
			win = true if (team_scores[0] > team_scores[1]) and (i == 0)
			win = true if (team_scores[1] > team_scores[0]) and (i == 1)
		end
	end

	return [["#{team_names[0]}", team_scores[0]], ["#{team_names[1]}", team_scores[1]], win]
end

def nyy_stories(num_stories = 5)
	#Top NYY headlines via rss
	nyy_feed_url = "http://mlb.mlb.com/partnerxml/gen/news/rss/nyy.xml"
	return get_rss_items(nyy_feed_url, num_stories)
end

def nyt_stories(num_stories = 5)
	#Top NYY headlines via rss
	nyt_feed_url = "http://feeds.nytimes.com/nyt/rss/HomePage"
	return get_rss_items(nyt_feed_url, num_stories)
end

###
#Configure Email
###

#Email-related params
@to_email = EMAIL_ADDR
@from_email = EMAIL_ADDR
@email_subject = "Digest for " + get_todays_date()
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

#Get yesterdays date
y = (Date.today - 1).to_s.split("-") #year, month, day
year = y[0]
month = y[1]
day = y[2]

@nyt_stories = nyt_stories()
@nyy_score = get_nyy_score(year, month, day)
@nyy_stories = nyy_stories(3)
@hn_stories = hn_stories()
@wsj_stories = wsj_stories()
@ee_stories = evening_edition_stories()

###
#Erb template
###
@template = %{
  <html>
    <head>
	<title></title>
	</head>
    <body>
		<h1>Digest for <%= get_todays_date() %></h1>
		<h2>NYT Headlines</h2>
			<ul>
				<% @nyt_stories.each do |story| %>
					<li><a href="<%= story.link %>"><%= story.title %></a></li>
				<% end %>
			</ul>
		<h2>WSJ Headlines</h2>
			<ul>
				<% @wsj_stories.each do |story| %>
					<li><a href=<%= story.link %>><%= story.title %></a></li>
				<% end %>
			</ul>
		<h2>Hacker News Headlines</h2>
			<ul>
				<% @hn_stories.each do |story| %>
					<li><a href=<%= story.link %>><%= story.title %></a></li>
				<% end %>
			</ul>
<% if @nyy_score != [] %>
	<% if @nyy_score[2] == true %>
		<% if @nyy_score[0][0] == "Yankees" %>
			<h2> Yankees beat <%= @nyy_score[1][0] %> <%= @nyy_score[0][1] %> - <%= @nyy_score[1][1] %></h2>
		<% else %>
			<h2> Yankees beat <%= @nyy_score[0][0] %> <%= @nyy_score[1][1] %> - <%= @nyy_score[0][1] %></h2>
		<% end %>
	<% else %>
		<% if @nyy_score[0][0] == "Yankees" %>
			<h2> Yankee lose to <%= @nyy_score[1][0] %> <%= @nyy_score[1][1] %> - <%= @nyy_score[0][1] %></h2>
		<% else %>
			<h2> Yankees lose to <%= @nyy_score[0][0] %> <%= @nyy_score[0][1] %> - <%= @nyy_score[1][1] %></h2>
		<% end %>
	<% end %>	
<% else %>
	<h2>The Yankees were off yesterday.</h2>
<% end %>
			<ul>
				<% @nyy_stories.each do |story| %>
					<li><a href=<%= story.link %>><%= story.title %></a></li>
				<% end %>
			</ul>
		<h2>Evening Edition Headlines</h2>
			<% @ee_stories.each_pair do |title,story| %>
				<h3><%= title %></h3>
				<p><%= story %></p>
			<% end %>
    </body>
  </html>
}.gsub(/^  /, '')

###
#Send digest email
###
body = ERB.new(@template)
puts body.result
email_body = Sanitize.clean(body.result, :elements => ['a', 'h1', 'h2', 'h3', 'p', 'ul', 'li'], :attributes => {'a' => ['href']}, :protocols => {'a' => {'href' => ['http', 'https', 'mailto']}})
puts email_body
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