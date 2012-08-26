##Digest - Evening Edition Module
##Retrieves headlines from evening-edition.com

require 'rubygems'
require 'mechanize'
require 'erb'

class DigestEveningEdition
	#When class is created, return the evening edition stories in html.
	def initialize(config)
		#Set indifferent access for args hash
		config.default_proc = proc do |h, k|
		   case k
			 when String then sym = k.to_sym; h[sym] if h.key?(sym)
			 when Symbol then str = k.to_s; h[str] if h.key?(str)
		   end
		end
		
		#Set EE url
		if config[:ee_url]
			@ee_url = config[:ee_url]
		else
			@ee_url = "http://evening-edition.com"
		end
	end
	
	def scrape()
		#Gonna have to page scrape this one
		a = Mechanize.new()
		a.get(@ee_url)
		story_titles_html = a.page.parser.xpath('/html/body/div[@class = "wrapper clearfix"]/section[@id = "news"]/div/article/h2')
		story_bodies_html = a.page.parser.xpath('/html/body/div[@class = "wrapper clearfix"]/section[@id = "news"]/div/article/p')
		@ee_stories = {}
		(0..5).each do |i|
			story_title = story_titles_html[i].to_s.gsub("<h2>" , "").gsub("</h2>" , "")
			story_body = story_bodies_html[i].to_s.gsub("<p>" , "").gsub("</p>" , "")
			@ee_stories[story_title] = story_body
		end
	end
	
	def to_html()
		#Scrape stories into @ee_stories hash
		self.scrape()
		
		@html = %{<h2>Evening Edition Headlines</h2>
			<% @ee_stories.each_pair do |title,story| %>
				<h3><%= title %></h3>
				<p><%= story %></p>
			<% end %>
			}.gsub(/^  /, '')
		return ERB.new(@html).result(binding)
	end
end