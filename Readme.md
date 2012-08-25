# Digest #

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

Additionally, the plugin's filename is expected to be the lowercase equivalent of this class's name.  For example, ```DigestRSS``` has a filename of ```digestrss.rb```.

## Testing ##

To test:
```
heroku run "ruby lib/senddigest.rb"
```