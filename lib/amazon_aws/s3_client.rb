# frozen_string_literal: true
require 'aws-sdk'

module AmazonAws
  class S3Client
    attr_reader :client, :region
    attr_accessor :bucket, :folder, :key, :acl

    def initialize(args={})
      secret_access_key = args.fetch(:secret_access_key, nil)  || S3_CONFIG.secret_access_key
      access_key   = args.fetch(:access_key, nil)  ||  S3_CONFIG.access_key
      @bucket      = args.fetch(:bucket, nil)      ||  S3_CONFIG.bucket
      @region      = args.fetch(:region, nil)      ||  S3_CONFIG.region
      @folder      = args.fetch(:folder, Rails.env)
      @key         = args.fetch(:path, nil)
      @acl         = args.fetch(:acl, 'public-read')

      client_arguments =  { region:  @region }
      if access_key && secret_access_key
        client_arguments[:credentials] = Aws::Credentials.new(access_key, secret_access_key)
      end

      @client = Aws::S3::Client.new(client_arguments)
    end


    def upload_file(file_name, absolute_path)
      @key ||= "#{@folder}/#{file_name}"
      resource = Aws::S3::Resource.new(client: @client)
      s3_object = resource.bucket(@bucket).object(key)

      begin
        s3_object.upload_file(absolute_path, acl: @acl)
        s3_object.public_url
      rescue Exception => e
        cf_notify_error_tracker(e, self.inspect)
        return ''
      end
    end

    def upload_content(file_name, content)
      @key ||= "#{@folder}/#{file_name}"

      begin
        response = @client.put_object(
          acl: @acl,
          bucket: @bucket,
          key: @key,
          body: content
          )
      rescue Exception => e
        cf_notify_error_tracker(e, self.inspect)
      end

      response&.successful? ? file_url(file_name) : ''
    end


    def file_url(file_name)
      @key ||= "#{@folder}/#{file_name}"
      s3_object = Aws::S3::Object.new(key: @key, bucket_name: @bucket, client: @client )
      s3_object.public_url
    end

    def delete(file_name)
      resource = Aws::S3::Resource.new(client: @client)
      s3_object = resource.bucket(@bucket).object(file_name)
      s3_object.delete
      # Alternate
      # Delete single object
      # resp = aws_client.delete_object({
      #   bucket: @bucket, # required
      #   key: "lines/11/1471931122/Sussex_Input.csv", # required
      #   use_accelerate_endpoint: false
      # })

    end

    def delete_multiple_files(files)
      # file_name =  "2015-09-20 Reigate 97 TR All Flagged.csv"
      # Sub Folder
      k = "development/2015-19-20/"
      objects = files.map do |file|
        new_hash = {}
        new_hash[:key] = k + file
        new_hash
      end

      # Delete multiple objects
      resp = @client.delete_objects({
        bucket: @bucket,
        delete: {
          objects: objects
          quiet: false,
        },
        use_accelerate_endpoint: false,
      })
    end

    # Collecting keys in a bucket objects
    def collect_bucket_keys
      resource = Aws::S3::Resource.new(client: @client)
      resource.bucket(@bucket).objects.collect(&:key)
    end

    # Retrieve bucket objects
    # same as collect_bucket_keys
    def retrieve_bucket_objects
      bucket = @client.buckets[@bucket].objects.collect(&:key)
    end
  end
end
