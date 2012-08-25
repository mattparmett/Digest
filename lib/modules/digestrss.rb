##Digest - RSS Module
##Retrieves top n stories from an rss feed when executed

require 'rubygems'
require 'rss'
require 'open-uri'
require 'date'
require 'erb'

class DigestRSS
	#When class is created, return the top n stories of the specified feed.
	#Defaults to entire feed (num_stories = 0)
	def initialize(config)		
		#For posterity (and access)
		@config = config
	
		@feeds = config['feeds']
		@stories = {}
		
		@feeds.each do |feed|
			feed_name = feed['name']
			feed_url = feed['url']
			num_stories = feed['num_stories']
			fresh = feed['fresh']
			sports = feed['type']
			rss_content = ""
			begin
				open(feed_url) { |f| rss_content = f.read }
			rescue OpenURI::HTTPError => e
				puts "Cannot open url: " + feed_url
			else
				@rss = RSS::Parser.parse(rss_content, false)
				if fresh
					stories = self.stories_after(Date.today - 1, num_stories)
				else
					if num_stories == 0 or num_stories.nil?
						stories = @rss.items
					else
						stories = @rss.items[0...num_stories]
					end
				end
			end
			@stories[feed_name] = stories #stories is an array of rss items (stories)
		end
	end
	
	#Gets stories posted on or after a certain date
	def stories_after(date, num_stories = 0)
		#Check if we have a date here
		if date.is_a? Date
			stories = []
			@rss.items.each do |story|
				#Date format: Thu, 16 Aug 2012 12:30:02 -0400
				s_date = story.date.to_s.split(" ")
				item_date = Date.new(s_date[3].to_i, Date::ABBR_MONTHNAMES.index(s_date[2]), s_date[1].to_i)
				#Compare to specified date
				stories << story if item_date >= date
				return stories if stories.length == num_stories
			end
			return stories
		else
			raise "Invalid date specified (not a Date): " + date
		end
	end
	
	def to_html()
		@digest_html = ""
		@feeds.each do |feed|
			#Special template for baseball news
			#I place this news directly below the score, so I don't want an <h2>
			puts feed['type']
			if feed['type'] == 'sports'
				html = %{<ul>
					<% @stories[feed['name']].each do |story| %>
						<li><a href="<%= story.link %>"><%= story.title %></a></li>
					<% end %>
				</ul>
				}.gsub(/^  /, '')
			elsif feed['type'] == 'news'
				html = %{<h2><%= feed['name'] %> Headlines</h2>
					<ul>
						<% @stories[feed['name']].each do |story| %>
							<li><a href="<%= story.link %>"><%= story.title %></a></li>
						<% end %>
					</ul>
				}.gsub(/^  /, '')
			end
			@digest_html << ERB.new(html).result(binding)
		end
		return @digest_html
	end
end