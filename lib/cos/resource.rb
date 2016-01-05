module COS

  class Resource

    attr_reader :options, :bucket, :path, :dir_count, :file_count

    def initialize(bucket, bucket_name, path, options = {})
      @options     = options
      @bucket      = bucket
      @path        = path
      @more        = options
      @results     = Array.new
      @dir_count   = 0
      @file_count  = 0
    end

    def next
      loop do
        # 从接口获取下一页结果
        fetch_more if @results.empty?

        # 取出结果
        r = @results.shift
        break unless r

        yield r
      end
    end

    def to_enum
      self.enum_for(:next)
    end

    def fetch
      client = bucket.client
      resp = client.api.list(path, options.merge({bucket: bucket.bucket_name}))

      @results = resp[:infos].map do |r|
        if r[:filesize].nil?
          # 目录
          COSDir.new(r.merge({
                                 bucket: bucket,
                                 path: Util.get_list_path(path, r[:name])
                             }))
        else
          # 文件
          COSFile.new(r.merge({
                                  bucket: bucket,
                                  path: Util.get_list_path(path, r[:name], true)
                              }))
        end
      end || []

      @dir_count  = resp[:dir_count]
      @file_count = resp[:file_count]

      @more[:context]  = resp[:context]
      @more[:has_more] = resp[:has_more]
    end

    def count
      @dir_count + @file_count
    end

    alias :size :count

    private

    def fetch_more
      return if @more[:has_more] === false
      fetch
    end

  end

  class ResourceOperator < Struct::Base

    required_attrs :bucket, :path, :name,  :ctime, :mtime
    optional_attrs :biz_attr, :filesize, :filelen, :sha, :access_url

    attr_reader :type, :api

    def initialize(attrs)
      super(attrs)
      @api = bucket.client.api
    end

    def state
      api.stat(path, bucket: bucket.bucket_name)
    end

    def update(biz_attr)
      api.update(path, biz_attr, bucket: bucket.bucket_name)
    end

    def delete
      api.delete(path, bucket: bucket.bucket_name)
    end

  end

  # COS文件资源
  class COSFile < ResourceOperator

    def initialize(attrs = {})
      super(attrs)
      @type = 'file'
    end

  end

  # COS目录资源
  class COSDir < ResourceOperator

    def initialize(attrs = {})
      super(attrs)
      @type = 'dir'
    end

    def upload

    end

    def list(options = {})
      bucket.list(path, options)
    end

    alias :ls :list

  end

end