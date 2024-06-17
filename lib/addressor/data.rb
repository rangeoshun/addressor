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

      def address?(way)
        !way.dig(:tags, 'addr:city').nil?
      end

      def transform(way)
        tags = way[:tags]

        {
          'city' => tags['addr:city'],
          'state' => tags['addr:state'],
          'county' => tags['addr:county'],
          'region' => tags['addr:region'],
          'postcode' => tags['addr:postcode'],
          'street' => tags['addr:street'],
          'number' => tags['addr:housenumber'],
          'unit' => tags['addr:unit']
        }
      end

      def digest_item(item)
        raw_address = transform(item)
        address = raw_address.transform_values { |value| normalize(value) }
        address.merge('country' => @prefixes.first)

        state, city, postcode, street, number, unit = address.values_at('state', 'city', 'postcode', 'street', 'number',
                                                                        'unit')
        postcode = deconstruct(postcode)
        street = deconstruct(street)
        path = [*@prefixes, state, city, *postcode, *street, number, unit].reject(&:nil?)

        @map.deep_set(path, raw_address)

        nil
      end

      def handle(item)
        digest_item(item) if address?(item)
        @bar.increment!
      end

      def collect_tagged
        puts('Collecting nodes')

        @bar.count = 0
        @pbf.seek(0)

        @pbf.each do |nodes, ways, rels|
          nodes.each { |item| handle(item) }
          ways.each { |item| handle(item) }
          rels.each { |item| handle(item) }
        end
      end

      def node_count
        return @node_count if @node_count

        puts('Counting nodes')

        @node_count = 0
        @bar.count = 0

        @pbf.each do |nodes, ways, rels|
          @node_count += [nodes.size, ways.size, rels.size].sum
          @bar.increment!
        end

        @node_count
      end

      def map
        return @map if @map

        @map = Map.new
        @bar.max = node_count

        collect_tagged

        @map
      end
    end
  end
end
