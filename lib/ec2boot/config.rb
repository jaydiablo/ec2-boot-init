module EC2Boot
    class Config
        attr_reader :user_data_url, :meta_data_url, :cache_dir, :actions_dir, :actions, :facts_file, :facts_yaml, :fact_add, :motd_file, :motd_template

        def initialize
            @user_data_url = "http://169.254.169.254/latest/user-data"
            @meta_data_url = "http://169.254.169.254/latest/meta-data/"
            @cache_dir = "/var/spool/ec2boot"
            @actions_dir = "/etc/ec2-boot-init/actions"
            @facts_file = "/etc/facts.txt"
            @facts_yaml = "/etc/mcollective/facts.yaml"
            @fact_add = "/usr/bin/fact-add"
            @motd_file = "/etc/motd"
            @motd_template = "/etc/ec2-boot-init/motd.provisioned"

            @actions = Actions.new(self)


            FileUtils.mkdir_p(@cache_dir)
        end
    end
end
