require 'date'

###
#Date Class Override
#(Because I'm lazy...)
###
class Date
	#Poorly-named method that splits a Date object into its component year, month, and day
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