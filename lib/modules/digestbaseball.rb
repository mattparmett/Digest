##Digest - Baseball Score Module
##Retrieves a team's score from specified date

require 'rubygems'
require 'rss'
require 'open-uri'
require 'date'
require File.expand_path(File.dirname(__FILE__)) + '/digestrss.rb'
require 'erb'

class DigestBaseball
	#When class is created, return the evening edition stories in html.
	def initialize(config)
		#Set args as instance vars
		@config = config
		@date = config['date']
		@team = config['team']
		@feed = config['feed']
		
		@game_result = self.get_game_result(@date, @team)
		@team_news_html = self.get_team_news(@feed)
		
		self.to_html()
	end
	
	def get_game_result(date, team)
		#Date
		date = date.to_s.split("-") #Format: YYYY-MM-DD
		year = date[0]
		month = date[1]
		day = date[2]
		
		#Construct usatoday mlb url for the specified day's scores
		usa_url = "http://content.usatoday.com/sportsdata/scores/mlb/#{year}/#{month}/#{day}"

		#Navigate to main usatoday mlb page
		a = Mechanize.new()
		a.get(usa_url)

		#Get link for yesterday's $TEAM game
		usa_page_links = a.page.parser.xpath('//a').map {|a| a['href']}
		game_link = ""
		usa_page_links.each {|a| game_link = a if a.include? "#{@team.downcase.titlecase}" and !(a.include? "schedule") and !(a.include? "game-story") }
		
		#If there is no $TEAM link found, there was no $TEAM game that day. Return empty array.
		if game_link == ""
			return []
		end
		
		#Get team names and scores for yesterday's yankees game
		a.get(game_link)
		team_names = Sanitize.clean(a.page.parser.xpath('//table[@class = "scorebox"]/tr/td[@class = "l"]').to_s).split("\n")
		team_scores = Sanitize.clean(a.page.parser.xpath('//table[@class = "scorebox"]/tr/td[@class = "c team-score"]').to_s).split("\n")
		
		#Determine if $TEAM won
		win = false
		team_names.each_index do |i|
			if team_names[i] == "#{@team.downcase.titlecase}"
				win = true if (team_scores[0] > team_scores[1]) and (i == 0)
				win = true if (team_scores[1] > team_scores[0]) and (i == 1)
			end
		end

		game_result = [["#{team_names[0]}", team_scores[0]], ["#{team_names[1]}", team_scores[1]], win]
		return game_result
	end
	
	def get_team_news(feed)
		#Shove feed into an argument that resembles DigestRSS's config arg
		config = {'feeds' => feed}
		
		#Create DigestRSS class
		rss_plugin = DigestRSS.new(config)
		
		#Get rss in html
		team_news_html = rss_plugin.to_html()
		
		return team_news_html
	end
	
	def result_to_html()
		@html = %{<% if @game_result != [] %>
	<% if @game_result[2] == true %>
		<% if @game_result[0][0] == "#{@team.downcase.titlecase}" %>
			<h2> <%= @team.downcase.titlecase %> beat <%= @game_result[1][0] %> <%= @game_result[0][1] %> - <%= @game_result[1][1] %></h2>
		<% else %>
			<h2> <%= @team.downcase.titlecase %> beat <%= @game_result[0][0] %> <%= @game_result[1][1] %> - <%= @game_result[0][1] %></h2>
		<% end %>
	<% else %>
		<% if @game_result[0][0] == "#{@team.downcase.titlecase}" %>
			<h2> <%= @team.downcase.titlecase %> lose to <%= @game_result[1][0] %> <%= @game_result[1][1] %> - <%= @game_result[0][1] %></h2>
		<% else %>
			<h2> <%= @team.downcase.titlecase %> lose to <%= @game_result[0][0] %> <%= @game_result[0][1] %> - <%= @game_result[1][1] %></h2>
		<% end %>
	<% end %>	
<% else %>
	<h2>The <%= @team.downcase.titlecase %> were off yesterday.</h2>
<% end %>
}.gsub(/^  /, '')
		return ERB.new(@html).result(binding)
	end
	
	def to_html()
		result_html = self.result_to_html()
		return result_html + @team_news_html
	end
end

class String
		#Methods to convert strings to titlecase.
		#Thanks https://github.com/samsouder/titlecase
		def titlecase
			small_words = %w(a an and as at but by en for if in of on or the to v v. via vs vs.)

			x = split(" ").map do |word|
			  # note: word could contain non-word characters!
			  # downcase all small_words, capitalize the rest
			  small_words.include?(word.gsub(/\W/, "").downcase) ? word.downcase! : word.smart_capitalize!
			  word
			end
			# capitalize first and last words
			x.first.smart_capitalize!
			x.last.smart_capitalize!
			# small words after colons are capitalized
			x.join(" ").gsub(/:\s?(\W*#{small_words.join("|")}\W*)\s/) { ": #{$1.smart_capitalize} " }
		end

		def smart_capitalize
			# ignore any leading crazy characters and capitalize the first real character
			if self =~ /^['"\(\[']*([a-z])/
			  i = index($1)
			  x = self[i,self.length]
			  # word with capitals and periods mid-word are left alone
			  self[i,1] = self[i,1].upcase unless x =~ /[A-Z]/ or x =~ /\.\w+/
			end
			self
		end

		def smart_capitalize!
			replace(smart_capitalize)
		end
end