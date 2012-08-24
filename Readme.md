To install:
```
heroku create
git push heroku master
heroku ps:scale web=0 worker=1 #make sure we have a worker process running, not a web (keeps the app free)
```

To configure:
```
heroku add:config gmail_user=[gmail username] gmail_password=[gmail password] email=[email address to send digest to]
```

To test:
```
heroku run "ruby cron.d/senddigest.rb"
```

To change the time of the daily email, edit the cron job line in ```worker.rb```:
```
scheduler.cron '0 12 * * *' do
```

More detailed documentation to come.

TODO:
Make system plug-and-play, so modules are used for news inputs rather than fixed code in ```senddigest.rb```.