require "sinatra/base"

module Avid
  class App < Sinatra::Base
    get '/' do
      "hello"
    end
  end
end
