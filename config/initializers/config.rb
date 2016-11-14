# frozen_string_literal: true
rack_env = ENV['RACK_ENV'] ||= 'development'
S3_CONFIG  = OpenStruct.new(YAML.load_file("../s3_config.yml")[rack_env])
