#Script to be run in cron on heroku and send daily email digest
#This shouldn't have to be touched by the user -- all the action happens in the plugins

require 'rubygems'
require 'yaml'
require 'ostruct'
require 'erb'
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8
LIB_PATH = File.expand_path(File.dirname(__FILE__)) + '/../lib/'
require LIB_PATH + 'plugin_manager.rb'
require LIB_PATH + 'date.rb'
require LIB_PATH + 'digestemail.rb'

###
#Constants
###

GMAIL_USER = ENV["gmail_username"]
GMAIL_PASS = ENV["gmail_password"]
EMAIL_ADDR = ENV["email"]
CFG_FILE = File.expand_path(File.dirname(__FILE__)) + '/../config.yml'


###
#Plugins
###

$APP_CONFIG = OpenStruct.new(YAML.load(ERB.new(File.read(CFG_FILE)).result))
plugin_manager = PluginManager.new()

###
#Email-related params
###

to_addr = EMAIL_ADDR
from_addr = EMAIL_ADDR
gmail = {
	:host => 'smtp.gmail.com',
	:port => '587',
	:enable_starttls_auto => true,
    :user_name            => GMAIL_USER,
    :password             => GMAIL_PASS,
    :authentication       => :plain, # :plain, :login, :cram_md5, no auth by default
    :domain               => "localhost.localdomain" # the HELO domain provided by the client to the server
}

###
#Create and send Digest email
###

digest_email = DigestEmail.new(:plugins => plugin_manager.plugins, :gmail_account => gmail)
digest_email.construct_body()
digest_email.send(to_addr, from_addr)