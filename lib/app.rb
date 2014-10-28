require 'sinatra/base'
require 'slim'
require 'hashids'
require './config/app.rb'

module Avid
  class App < Sinatra::Base
    HASHIDS = Hashids.new "#{Random.new(1).rand}#{Time.now}"
    RANDOMS = Random.new(Time.now.to_i)

    VIDEO_ROOT = File.expand_path(File.dirname(__FILE__) + '/../public/v')
    PUBLIC_DIR = File.dirname(__FILE__) + '/../public'

    # enable public folder resource
    set :public_dir, PUBLIC_DIR

    # show video
    get '/:videoid' do
      @videoid = params[:videoid]
      slim :index
    end

    # upload file
    post '/upload' do
      unless params[:file] &&
            (tmpfile = params[:file][:tempfile]) &&
            (name = params[:file][:filename])
        return halt 500, "No file selected"
      end

      hash = HASHIDS.encode(RANDOMS.rand(100), Time.now.to_f)
      STDERR.puts "Uploading file, original name #{name.inspect}"
      save_path = File.expand_path("#{VIDEO_ROOT}/#{hash}.mp4")

      STDERR.puts "save_path: #{save_path}"

      File.open(save_path, 'wb') do |f|
        f.write tmpfile.read
      end

      "http://localhost:1028/#{hash}"
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
