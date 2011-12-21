require "yaml"

module EC2Boot
    class Util
        # Fetches a url, it will retry 5 times if it still
        # failed it will return ""
        #
        # If an optional file is specified it will write
        # the retrieved data into the file in an efficient way
        # in this case return data will be true or false
        #
        # raises URLNotFound for 404s and URLFetchFailed for
        # other non 200 status codes
        def self.get_url(url, file=nil)
            uri = URI.parse(url)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = (uri.scheme == 'https')

            retries = 5

            begin
                if file
                    dest_file = File.open(file, "w")
                    response = http.get(uri.path) do |r|
                        dest_file.write r
                    end
                    dest_file.close
                else
                    response = http.get(uri.path)
                end

                raise URLNotFound if response.code == "404"
                raise URLFetchFailed, "#{url}: #{response.code}" unless response.code == "200"

                if response.code == "200"
                    if file
                        return true
                    else
                        return response.body
                    end
                else
                    if file
                        return false
                    else
                        return ""
                    end
                end
            rescue Timeout::Error => e
                retries -= 1
                sleep 1
                retry if retries > 0

            rescue URLFetchFailed => e
                retries -= 1
                sleep 1
                retry if retries > 0
            end
        end

        # Logs to stdout and syslog
        def self.log(msg)
            puts "#{Time.now}> #{msg}"
            system("logger #{msg}")
        end

        # updates the motd, updates all @@foo@@ variables
        # with data from the facts
        def self.update_motd(ud, md, config)
            templ = File.readlines(config.motd_template)
            if ud.user_data.is_a?(Hash) && ud.user_data.include?(:facts) && ud.user_data[:facts].include?(:hostname)
              hostname = ud.user_data[:facts][:hostname]
            else
              hostname = md.flat_data["hostname"]
            end
            File.open(config.motd_file, "w") do |motd|
                templ.each do |line|
                    if md.fetched?
                        line.gsub!(/@@ami_id@@/, md.flat_data["ami_id"])
                        line.gsub!(/@@instance_type@@/, md.flat_data["instance_type"])
                        line.gsub!(/@@placement_availability_zone@@/, md.flat_data["placement_availability_zone"])
                        line.gsub!(/@@hostname@@/, hostname)
                        line.gsub!(/@@public_hostname@@/, md.flat_data["public_hostname"])
                    end

                    motd.write line
                end
            end
        end

        # writes out the facts file
        def self.write_facts(ud, md, config)
            facts = Hash.new

            if ud.fetched?
                if ud.user_data.is_a?(Hash)
                    if ud.user_data.include?(:facts)
                        ud.user_data[:facts].each_pair do |k,v|
                            self.write_fact(k, v, config)
                            facts[k] = v
                        end
                    end
                end
            end

            # EC2 metadata (Facter does this automatically now)
            #if md.fetched?
            #    data = md.flat_data
            #
            #    data.keys.sort.each do |k|
            #        %x[#{config.fact_add} #{self.shellescape('ec2_' + k)} #{self.shellescape(data[k])}]
            #    end
            #end

            #if data.include?("placement_availability_zone")
            #    self.write_fact("ec2_placement_region", data["placement_availability_zone"].chop, config)
            #    facts["ec2_placement_region"] = data["placement_availability_zone"].chop
            #end

            if config.facts_yaml
                existing_facts = YAML::load(File.open(config.facts_yaml))
                if !existing_facts.is_a?(Hash)
                    existing_facts = Hash.new
                end

                # Merge existing with new, overriding with new facts
                existing_facts.update(facts)

                # Write facts to yaml file
                File.open(config.facts_yaml, "w") do |f|
                    f.write(existing_facts.to_yaml)
                end
            end
        end

        def self.write_fact(k, v, config)
            if config.fact_add
                %x[#{config.fact_add} #{self.shellescape(k)} #{self.shellescape(v)}]
            end
        end
        
        def self.shellescape(str)
            # An empty argument will be skipped, so return empty quotes.
            return "''" if str.empty?

            str = str.dup

            # Process as a single byte sequence because not all shell
            # implementations are multibyte aware.
            str.gsub!(/([^A-Za-z0-9_\-.,:\/@\n])/n, "\\\\\\1")

            # A LF cannot be escaped with a backslash because a backslash + LF
            # combo is regarded as line continuation and simply ignored.
            str.gsub!(/\n/, "'\n'")

            return str
        end

        def self.update_hostname(ud, md, config)
          if ud.user_data.is_a?(Hash) && ud.user_data.include?(:facts)
             if ud.user_data[:facts].include?(:hostname)
                `hostname #{ud.user_data[:facts][:hostname]}`
             end
          end
        end
    end
end
