require 'benchmark'
require 'pry'
require 'rapidjson'
require 'progress_bar'
require 'stringex'
require 'pbf_parser'

MAP_PATH = 'data/generated'

@address_maps = nil

def normalize(str)
  return str if str.nil?

  str
    .downcase
    .to_ascii
    .bytes
    .filter { |b| b <= 0x7a && b >= 0x61 || b <= 0x39 && b >= 0x30 || b == 0x20 || b == 0x2d || b == 0x2f }
    .map { |b| b.chr(Encoding::UTF_8) }
    .join('')
end

def deconstruct(str)
  return [] if str.nil?

  normalize(str).split(' ')
end

def parse_prefixes(path)
  split_path = path.split('/')
  file_name = split_path.last
  dirs = split_path - [file_name, 'data', 'geojson', 'osm']

  [*dirs].map { |str| deconstruct(str) }.flatten
end

def deep_set(keys, target, value)
  first_key = keys.slice!(0)

  return target[first_key] = value if keys.empty?

  target[first_key] ||= {}

  deep_set(keys, target[first_key], value)
rescue StandardError => e
  # puts e
  # puts value
end

def find_files(path, files = [])
  Dir
    .entries(path)
    .reject { |entry| entry.start_with?('.') }
    .each do |entry|
      full_entry = "#{path}/#{entry}"
      if File.directory?(full_entry)
        find_files(full_entry, files)
      elsif File.file?(full_entry)
        files << full_entry
      end
    end

  files
end

def count_rows(files)
  files.map(&:size).sum
end

def find_unit(address_ary, address_found)
  unit_found = address_ary
               .map { |part| address_found[part] }
               .compact
               .first

  unit_found || address_found
end

def find_address(address_ary, maps)
  return if maps.empty?

  address_found = maps.find { |map| map['number'] }
  return find_unit(address_ary, address_found) if address_found

  next_maps = address_ary
              .map { |part| maps.map { |map| map[part] || part } }
              .flatten
              .reject { |part| part.is_a?(String) }

  find_address(address_ary, next_maps)
end

def file_count(pbf)
  pbf.seek(-1)
  count = pbf.pos
  pbf.seek(0)
  count
end

def address?(item)
  !item[:tags]['addr:street'].nil?
end

def transform_item(item)
  tags = item[:tags]

  {
    'city' => tags['addr:city'],
    'postcode' => tags['addr:postcode'],
    'street' => tags['addr:street'],
    'number' => tags['addr:housenumber'],
    'unit' => tags['addr:unit']
  }
end

def digest_item(acc, item, prefixes = [])
  raw_address = transform_item(item)
  address = raw_address.transform_values { |value| normalize(value) }
  address.merge('country' => prefixes.first)
  address.merge('region' => address['city']) if address['region'].nil?

  state, city, postcode, street, number, unit = address.values_at('state', 'city', 'postcode', 'street', 'number',
                                                                  'unit')
  postcode = deconstruct(postcode)
  street = deconstruct(street)
  path = [*prefixes, state, city, *postcode, *street, number, unit].reject(&:nil?)

  deep_set(path, acc, raw_address)

  nil
end

def collect_tagged(pbf, bar, prefixes)
  pbf.seek(0)

  acc = {}

  pbf.each do |nodes, ways, rels|
    nodes.each do |node|
      digest_item(acc, node, prefixes) if address?(node)
      bar.increment!
    end
    ways.each do |way|
      digest_item(acc, way, prefixes) if address?(way)
      bar.increment!
    end
    rels.each do |rel|
      digest_item(acc, rel, prefixes) if address?(rel)
      bar.increment!
    end
  end

  acc
end

def generate_map(path)
  puts('Counting nodes')

  pbf = PbfParser.new(path)
  prefixes = parse_prefixes(path)

  bar = ProgressBar.new(file_count(pbf))
  node_count = 0

  pbf.each do |nodes, ways, rels|
    node_count += [nodes.size, ways.size, rels.size].sum
    bar.increment!
  end

  puts('Collecting nodes')

  bar.max = node_count
  bar.count = 0

  collect_tagged(pbf, bar, prefixes)
end

def generate_maps
  files = find_files('data/osm')

  files.map.with_index do |path, index|
    puts("Processing file (#{index + 1}/#{files.size}): #{path}")

    map = generate_map(path)
    persist_map(map, index)

    map
  end

  bar = ProgressBar.new(sio.size)
  name = File.join(MAP_PATH, "#{map.keys.first}-#{postfix}.json")

  puts("Dumping JSON to: #{name}")

  File.delete(name) if File.exist?(name)

  output = File.open(name, 'w') do |file|
    sio.each_char do |char|
      file << char
      bar.increment!
    end
  end

  output.close
end

def load_maps
  Dir
    .entries(MAP_PATH)
    .reject { |entry| entry.start_with?('.') }
    .map do |entry|
      file = File.open(entry)
      RapidJSON.parse(file.read)
    end
end

if ARGV.include?('-o') || find_files(MAP_PATH).empty?
  @address_maps = generate_maps
else
  @address_maps ||= load_maps
end

@maps = [
  @address_maps,
  @address_maps.map(&:values)
].flatten

while true
  puts ''
  puts ''
  print 'address> '
  address = $stdin.gets.strip
  parsed = nil

  puts(Benchmark.measure do
    parsed = find_address(deconstruct(address), @maps)
  end)

  p parsed
end
