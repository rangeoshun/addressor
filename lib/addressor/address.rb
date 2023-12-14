# frozen_string_literal: true

require 'stringex'

class Addressor
  module Address
    def right?(byte)
      byte <= 0x7a && byte >= 0x61 || byte <= 0x39 && byte >= 0x30 || byte == 0x20 || byte == 0x2d || byte == 0x2f
    end

    def normalize(str)
      return str if str.nil?

      str
        .downcase
        .to_ascii
        .bytes
        .filter { |byte| right?(byte) }
        .map { |byte| byte.chr(Encoding::UTF_8) }
        .join('')
    end

    def deconstruct(str)
      return [] if str.nil?

      normalize(str).split(' ')
    end
  end
end
