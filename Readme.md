# Digest #

Digest is an extensible platform written in Ruby for sending a daily email newsletter.  Digest is meant to be deployed to a free Heroku instance and used personally; Digest is written to only accept one subscribed email address.  On a certain schedule (configurable -- see below), Digest will execute configured plugins and use their output to construct and send an HTML email.

## Installation ##

```
git clone https://github.com/mattparmett/Digest.git
cd Digest
bundle install
heroku create
git push heroku master
heroku ps:scale web=0 worker=1 #make sure we have a worker process running, not a web (keeps the app free)
```

## Configuration ##

Immediately after installing Digest, you'll want to configure it to send you email using your Gmail account:

```
heroku add:config gmail_user=[gmail username] gmail_password=[gmail password] email=[email address to send digest to]
```

Your login credentials are stored as envirnomental variables, so they're inaccessible outside of your Heroku instance of Digest.

To change the time of the daily email, edit the cron job line in ```worker.rb```:
```
scheduler.cron '0 12 * * *' do
```

### Config.yml ###

Plugins are managed in the ```config.yml``` file located in the project root.  To tell Digest to include and use a plugin, you must add it to ```config.yml```.

At minimum, you must pass the plugin's name, which must be the same as the plugin's class name (i.e. the name of the class that includes the required ```to_html()``` method).  Other parameters can be passed, depending on the needs of the plugin.  (See the included ```config.yml``` for reference.)

## Plugins ##

Digest features a (rudimentary) plugin system to allow you to easily generate and include html content in the digest email.

Plugins are ```.rb``` files located in ```lib/modules/```.  All plugins located in that directory are loaded and executed by ```senddigest.rb```, so there are some guidelines to ensure uniformity (see included plugins for reference):

### The Plugin Class ###

While the plugin's ```.rb``` file can include multiple classes, there must be one class that has a method titled ```to_html()```.  The ```to_html()``` method is responsible for returning valid html to ```senddigest.rb``` to be included in the Digest email.  The plugins I've written use ERB to programmatically create valid html.  The html returned by ```to_html()``` is placed inside ```<body>``` tags, below the email title (an ```<h1>```).

The plugin name configured in ```config.yml``` must be the same as the name of the class that includes the ```to_html()``` method.  The plugin manager automatically creates a new instance of this class when Digest is executed; therefore, you should use this class's ```initialize``` method to retrieve configuration data from ```config.yml``` like so:

```ruby
def initialize(config)
	# config is a hash containing the keys/values passed in config.yml
	# For example, config['name'] is the plugin name
end
```

And here's an example ```to_html()``` method, from ```digesteveningedition.rb```:

```ruby
def to_html()
	@html = %{<h2>Evening Edition Headlines</h2>
		<% @ee_stories.each_pair do |title,story| %>
			<h3><%= title %></h3>
			<p><%= story %></p>
		<% end %>
		}.gsub(/^  /, '')
	return ERB.new(@html).result(binding)
end
```

Additionally, the plugin's filename is expected to be the lowercase equivalent of this class's name.  For example, ```DigestRSS``` has a filename of ```digestrss.rb```.

## Testing ##

To test:
```
heroku run "ruby lib/senddigest.rb"
```

## Acknowledgements ##

[Crony](https://github.com/thomasjachmann/crony) -- Digest is based on Crony, a lightweight, free alternative to Heroku's cron add-on developed by [Thomas Jachmann](https://github.com/thomasjachmann).

[Rufus-Scheduler](https://github.com/jmettraux/rufus-scheduler) -- Powers Crony's cron mechanism.

[Siriproxy](https://github.com/plamoni/SiriProxy) -- Digest's idea of plugins and a plugin manager came from siriproxy.