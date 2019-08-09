require 'yaml'

# parses config file
module Config
  def self.config
    YAML.load_file('config.yml')
  end
end
