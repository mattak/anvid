require 'sinatra/base'
require 'slim'
require 'hashids'
require './config/app.rb'

require 'json'
require 'redis'

module Rodeo
  class App < Sinatra::Base
    HASHIDS = Hashids.new "#{Random.new(1).rand}#{Time.now}"
    RANDOMS = Random.new(Time.now.to_i)

    VIDEO_ROOT = File.expand_path(File.dirname(__FILE__) + '/../public/raw/v')
    IMAGE_ROOT = File.expand_path(File.dirname(__FILE__) + '/../public/raw/p')
    PUBLIC_DIR = File.dirname(__FILE__) + '/../public'

    EXPIRE_TIME = 60 * 60 * 24 * 3 # 60 * 60 * 24 * 3 second => 3days

    # setup db
    configure do
      enable :sessions
      set :redis, Redis.new(host:APP_DB_HOST, port:APP_DB_PORT)
    end

    # enable public folder resource
    set :public_dir, PUBLIC_DIR

    helpers do
      def _stash_key key
        "rodeo:#{key}"
      end

      def stash_get key
        key = _stash_key key
        val = settings.redis.get(key)
        p val
        nil != val ? JSON.parse(val) : nil
      end

      def stash_getall
        keys = settings.redis.keys

        if nil != keys
          keys.select do |key|
            key[/^rodeo:/]
          end.collect do |key|
            key.sub(/^rodeo:/,"")
          end.inject([]) do |sum,key|
            val = stash_get key
            key = _stash_key key
            sum << val
          end
        else
          []
        end
      end

      def stash_set key, obj
        key = _stash_key key

        if nil != obj
          settings.redis.set(key, JSON.generate(obj))
          settings.redis.expire(key, EXPIRE_TIME)
        else
          nil
        end
      end

      def stash_clean
        keys = settings.redis.keys

        if nil != keys
          keys.select do |key|
            key[/^rodeo:/]
          end.collect do |key|
            settings.redis.del key
          end
        end
      end
    end

    # show video
    get '/v/:videoid' do
      @videoid = params[:videoid]
      @data = stash_get params[:videoid]
      @title = "#{ @data['product_model'] } #{ @data['screen_size'] } / #{ @data['sdk_version_name'] } / #{ @data['sf_lcd_density'] }"
      @title = "#{ @title } - Record by rodeo"
      slim :video
    end

    # show image
    get '/p/:imageid' do
      @imageid = params[:imageid]
      @data = stash_get params[:imageid]
      @title = "#{ @data['product_model'] } #{ @data['screen_size'] } / #{ @data['sdk_version_name'] } / #{ @data['sf_lcd_density'] }"
      @title = "#{ @title } - Capture by rodeo"
      slim :image
    end

    # upload video
    post '/upload' do
      unless params[:file] &&
            (tmpfile = params[:file][:tempfile]) &&
            (name = params[:file][:filename])
        return halt 500, "No file selected"
      end

      hash = HASHIDS.encode(RANDOMS.rand(100), Time.now.to_f)
      STDERR.puts "Uploading file, original name #{name.inspect}"

      case name
      when /\.png$/i
        url_path = "/p/#{hash}"
        save_path = File.expand_path("#{IMAGE_ROOT}/#{hash}.png")
      when /\.mp4$/i
        url_path = "/v/#{hash}"
        save_path = File.expand_path("#{VIDEO_ROOT}/#{hash}.mp4")
      else
        return halt 500, "The file is not supporting."
      end

      STDERR.puts "save_path: #{save_path}"

      File.open(save_path, 'wb') do |f|
        f.write tmpfile.read
      end

      if nil != params[:data]
        data = JSON.parse(params[:data])
        data.merge(hashid: hash)
        stash_set hash, data
      end

      "#{APP_URL}#{url_path}"
    end

    # get script
    get '/sh/:name' do
      file = PUBLIC_DIR + '/bin/' + params[:name]
      halt 404, "Script not found" unless File.exists?(file)

      content = File.read(file)
      content.sub /\nAPP_URL=[^\n]+/, "\nAPP_URL=#{APP_URL}"
    end
  end
end
