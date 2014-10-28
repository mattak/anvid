require 'sinatra/base'
require 'slim'

module Avid
  class App < Sinatra::Base

    VIDEO_ROOT = File.expand_path(File.dirname(__FILE__))
    set :public_dir, File.dirname(__FILE__) + '/../public'

    get '/:videoid' do
      @videoid = params[:videoid]
      slim :index
    end
  end
end
