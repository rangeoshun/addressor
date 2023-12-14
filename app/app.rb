# frozen_string_literal: true

require 'benchmark'
require 'pry'
require 'rapidjson'

require_relative '../lib/addressor'

class App
  def initialize
    @addressor = Addressor.new
  end

  def call(env)
    req = Rack::Request.new(env)
    query = req.params['address']
    headers = { 'Content-Type': 'application/json' }
    body = nil

    puts(Benchmark.measure do
           body = RapidJSON.dump(@addressor.find(query))
         end)

    [
      200,
      headers,
      [body]
    ]
  end
end
