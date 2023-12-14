# frozen_string_literal: true

require_relative 'addressor/address'
require_relative 'addressor/data'
require_relative 'addressor/map'

class Addressor
  MAP_PATH = 'data/generated'

  include Address

  def initialize
    @maps = if Data.find(MAP_PATH).empty?
              generate_osm_maps
            else
              load_maps
            end

    @maps = [
      @maps,
      @maps.map(&:values)
    ].flatten
  end

  def generate_osm_maps
    files = Data.find_osms

    files.map.with_index do |path, index|
      puts("Processing file (#{index + 1}/#{files.size}): #{path}")

      osm = Data::OSM.new(path)
      map = osm.map
      map.persist!

      map
    end
  end
  private :generate_osm_maps

  def load_maps
    Dir
      .entries(MAP_PATH)
      .reject { |entry| entry.start_with?('.') }
      .map do |entry|
        path = File.join(MAP_PATH, entry)
        file = File.open(path)

        puts("Parsing #{path}")

        RapidJSON.parse(file.read)
      end
  end
  private :load_maps

  def find_unit(address_ary, address_found)
    unit_found = address_ary
                 .map { |part| address_found[part] }
                 .compact
                 .first

    unit_found || address_found
  end
  private :find_unit

  def find(address_str)
    address_ary = deconstruct(address_str)
    find_address(address_ary)
  end

  def find_address(address_ary, maps = @maps)
    return if maps.empty?

    address_found = maps.find { |map| map['number'] && map['postcode'] }
    return find_unit(address_ary, address_found) if address_found

    next_maps = address_ary
                .map { |part| maps.map { |map| map[part] || part } }
                .flatten
                .reject { |part| part.is_a?(String) }

    find_address(address_ary, next_maps)
  end
end
