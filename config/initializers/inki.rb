config = YAML.load_file(Rails.root.join('config', 'inki.yml'))[Rails.env]
Rails.configuration.inki = OpenStruct.new(config)
Rails.configuration.i18n.available_locales = Rails.configuration.inki.languages.keys
require "inki"
