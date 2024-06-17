# frozen_string_literal: true

require 'pbf_parser'
require 'progress_bar'

class Addressor
  class Data
    class << self
      include Address

      def handle(entry, path, files)
        full_entry = "#{path}/#{entry}"

        return find(full_entry, files) if File.directory?(full_entry)

        files << full_entry
      end
      private :handle

      def find(path, files = [])
        Dir
          .entries(path)
          .reject { |entry| entry.start_with?('.') }
          .each { |entry| handle(entry, path, files) }

        files
      end

      def find_osms
        find('data/osm')
      end

      def parse_prefixes(path)
        split_path = path.split('/')
        file_name = split_path.last
        dirs = split_path - [file_name, 'data', 'geojson', 'osm']

        dirs.map { |str| deconstruct(str) }.flatten
      end
    end

    class OSM
      include Address

      def initialize(path)
        @pbf = PbfParser.new(path)
        @bar = ProgressBar.new(0, :bar, :counter, :percentage, :eta)
        @prefixes = Data.parse_prefixes(path)
        @node_count = nil
      end

      def file_count
        @pbf.seek(-1)
        count = @pbf.pos
        @pbf.seek(0)
        count
      end

      def address?(item)
        item.dig(:tags, 'addr:country') == 'HU' &&
          (item.dig(:tags, 'addr:housenumber') ||
          item.dig(:tags, 'addr:interpolation'))
      end

      def transform(item)
        tags = item[:tags]

        {
          'city' => tags['addr:city'],
          'state' => tags['addr:state'],
          'county' => tags['addr:county'],
          'country' => tags['addr:country'],
          'region' => tags['addr:region'],
          'postcode' => tags['addr:postcode'],
          'street' => tags['addr:street'],
          'number' => tags['addr:housenumber'],
          'interpolation': tags['addr:interpolation'],
          'unit' => tags['addr:unit']
        }
      end

      def digest_item(item, map)
        raw_address = transform(item)
        address = raw_address.transform_values { |value| normalize(value) }

        country, state, city, postcode,
        street, interpolation, number, unit = address.values_at('country', 'state', 'city', 'postcode',
                                                                'street', 'interpolation', 'number', 'unit')
        postcode = deconstruct(postcode)
        street = deconstruct(street)
        path = [*@prefixes, country, state, city, *postcode, *street, interpolation, number, unit].uniq.reject(&:nil?)

        map.deep_set(path, raw_address)

        nil
      end

      def handle(item, map)
        digest_item(item, map) if address?(item)
        @bar.increment!
      end

      def collect_tagged
        i = 0
        @pbf.seek(i)
        @maps = []

        loop do
          i += 1
          puts("Collecting nodes from file #{i}/#{@pbf.size}")

          map = Map.new

          @bar.count = 0
          @bar.max = @pbf.nodes.size + @pbf.ways.size + @pbf.relations.size
          @pbf.nodes.each { |item| handle(item, map) }
          @pbf.ways.each { |item| handle(item, map) }
          @pbf.relations.each { |item| handle(item, map) }
          @bar.count = @bar.max

          map.persist! unless map.empty?
          @maps << map

          break unless @pbf.next
        end
      end

      def map
        return @maps if @maps

        collect_tagged
      end
    end
  end
end
