newaction("getactions") do |cmd, ud, md, config|
    if cmd.include?(:url)
        url = cmd[:url]

        EC2Boot::Util.log("Fetching action list from #{url}")

        list = EC2Boot::Util.get_url(url)
        action_url = url.split('/')[0..-2].join('/')
        list.split("\n").each do |command|
            EC2Boot::Util.log("Fetching command: #{action_url}/#{command}")

            body = EC2Boot::Util.get_url("#{action_url}/#{command}")

            File.open(config.actions_dir + "/#{command}", "w") do |f|
                f.print body
            end
        end

        config.actions.load_actions
    end
end
