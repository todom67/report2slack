# Reporting details:  https://api.slack.com/docs/message-formatting

require 'puppet'
require 'yaml'
require 'json'

Puppet::Reports.register_report(:report2slack) do
	if (Puppet.settings[:config]) then
		configfile = File.join([File.dirname(Puppet.settings[:config]), "report2slack.yaml"])
	else
		configfile = "/etc/puppetlabs/puppet/report2slack.yaml"
	end
	raise(Puppet::ParseError, "Config file #{configfile} not readable") unless File.exist?(configfile)
	config = YAML.load_file(configfile)

	DISABLED_FILE = File.join([File.dirname(Puppet.settings[:config]), 'report2slack_disabled'])
	SLACK_WEBHOOK_URL = config['webhook_url']
	SLACK_CHANNEL = config['channel']
	PUPPETCONSOLE = config['puppetconsole']
    ICON_URL = config['icon_url']

	def process
        # Find out if we should be disabled
		disabled = File.exists?(DISABLED_FILE)

        # Open a file for debugging purposes
        f = File.open('/var/log/puppetlabs/puppetserver/report2slack.log','w') 

        # We only want to send a report if we have a corrective change
        if (self.status == "changed") then
			if (self.corrective_change == true) then
				real_status = "#{self.status} (corrective)"
			elsif (self.corrective_change == false) then
				real_status = "#{self.status} (intentional)"
			else
				real_status = "#{self.status} (unknown - #{self.corrective_change})"
			end
		else
			real_status = "#{self.status}"
        end
        f.write("Status: #{real_status}")

        level = ''
        log_mesg = "" 
		if (self.logs.length > 0) then
		  self.logs.length.times do |count|
            level = self.logs[count].level

            f.write("DEBUG: [#{self.logs[count].level}] #{self.logs[count].message}\n")
            if (level =~ /info/i) then
              if( self.logs[count].message.include? "FileBucket got a duplicate file" ) then
                  log_mesg = "#{log_mesg}\n#{self.logs[count].message.chomp}"
              end
            else  
              next if self.logs[count].message.include? "{md5}"
              next if self.logs[count].message.include? "Applied catalog in"
              next if self.logs[count].message == ''
               
              #log_mesg = "#{log_mesg}\n#{self.logs[count].line} #{self.logs[count].file}\n#{self.logs[count].message.chomp}"
              f.write("Source: #{self.logs[count].line} #{self.logs[count].file}")
              log_mesg = "#{log_mesg}\n#{self.logs[count].message.chomp}"
            end

          end
		end
        log_mesg.gsub!(/"/, '')
        log_mesg.gsub!(/'/, '')

		whoami = %x( hostname -f ).chomp
        msg = "Puppet run for <https://#{PUPPETCONSOLE}/#/node_groups/inventory/node/#{self.host}/reports|#{self.host}> *#{real_status}* on #{self.configuration_version} in #{self.environment}"
        headers = '--header "Content-type: application/json"'
			
		#TODO give an array of status to choose from
        #TODO add a button for the report directly, will need to lookup first
        #TODO add a button for the opened change request, SNOW at first
       
        # Don't run if we are disabled, not a corrective change or in noop mode 
        if (!disabled && self.corrective_change == true && self.noop == false) then
            attachment = %Q{[ {
              "pretext":"Log Summary",
              "title_link":"https://#{PUPPETCONSOLE}/#/node_groups/inventory/node/#{self.host}/reports",
              "title":"Full node report available from the Puppet Master",
              "text":"#{log_mesg}",
              "color":"##ff9900",
              "ts":"#{self.configuration_version}",
            } ]}

            payload = %Q{ {
              "channel":"#{SLACK_CHANNEL}",
              "icon_url":"#{ICON_URL}",
              "username":"#{whoami}",
              "text":"#{msg}",
              "attachments":#{attachment},
            } }
            
            f.write("-- Start of change --\n")
            f.write("URL: #{SLACK_WEBHOOK_URL}\n")
            f.write("Payload: #{payload}\n")

            # We are using CURL on purpose because the rest-client requires a newer version of ruby then what's in
            # the puppetserver jruby renvironment
			result = %x(curl -X POST #{headers} --data '#{payload}' #{SLACK_WEBHOOK_URL} ).chomp

            f.write("Exit code: #{$?} #{$?.exitstatus}\n")
            f.write("Result: #{result}\n")
            f.write("-- End of change --\n\n")
        else
            f.write("Not submitting report: #{disabled} #{self.corrective_change} #{self.noop}\n")
        end
        f.close
	end
end
