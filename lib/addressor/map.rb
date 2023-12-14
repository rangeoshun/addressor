# frozen_string_literal: true

require 'rapidjson'
require 'securerandom'

class Addressor
  class Map < Hash
    def initialize
      super
      @id = SecureRandom.hex(8)
    end

    def deep_set(keys, value, target = self)
      first_key = keys.slice!(0)

      return target[first_key] = value if keys.empty?

      target[first_key] ||= {}

      deep_set(keys, value, target[first_key])
    rescue StandardError => e
      # puts e
      # puts value
    end

    def write_to(path, sio)
      output = File.open(path, 'w') do |file|
        sio.each_char do |char|
          file << char
          @bar.increment!
        end
      end

      output.close
      output
    end

    def to_json(*_args)
      StringIO.new(RapidJSON.dump(self))
    end

    def path
      File.join(MAP_PATH, "#{keys.first}-#{@id}.json")
    end

    def persist!
      sio = to_json
      @bar = ProgressBar.new(sio.size)

      puts("Dumping JSON to: #{path}")

      File.delete(path) if File.exist?(path)

      write_to(path, sio)
    end
  end
end
