#Helper class to manage plugins
class PluginManager
	attr_reader :plugins
	
	def initialize()
		load_plugins()
	end

	def load_plugins()
		@plugins = []
		if $APP_CONFIG.plugins
		  $APP_CONFIG.plugins.each do |pluginConfig|
			  if pluginConfig.is_a? String
				className = pluginConfig
				requireName = "#{className.downcase}"
			  else
				className = pluginConfig['name']
				requireName = pluginConfig['require'] || "#{className.downcase}"
			  end
			  require File.expand_path(File.dirname(__FILE__)) + "/../modules/" + requireName
			  plugin = Kernel.const_get(className).new(pluginConfig)
			  @plugins << plugin
		  end
		end
		#puts "Plugins loaded: #{@plugins}"
	end
end
