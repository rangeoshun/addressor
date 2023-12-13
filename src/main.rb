require 'benchmark'
require 'pry'
require 'rapidjson'
require 'progress_bar'
require 'stringex'
require 'pbf_parser'

MAP_PATH = 'data/generated/address-map.json'

@address_map = nil
@bar = nil
@count = 0
@files = []

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
  dirs = split_path - [file_name, 'data', 'geojson']
  city = file_name.split('-').first

  [*dirs, city].map { |str| deconstruct(str) }.flatten
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
        find_files(full_entry)
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
  !item[:tags]["addr:street"].nil?
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

  city, postcode, street, number, unit = address.values_at('city', 'postcode', 'street', 'number', 'unit')
  postcode = deconstruct(postcode)
  street = deconstruct(street)
  path = [*prefixes, city, *postcode, *street, number, unit].reject(&:nil?)

  deep_set(path, acc, raw_address)

  nil
end

def collect_tagged(pbf, bar)
  pbf.seek(0)

  acc = {}
  prefixes = [pbf.instance_variable_get(:@filename).split('/').last.split('-').first]

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

def generate_map
  files = find_files('data/osm')
  pbf = PbfParser.new(files.first)
  puts('Counting nodes')
  bar = ProgressBar.new(file_count(pbf))
  node_count = 0
  pbf.each do |nodes, ways, rels|
    node_count += [nodes.size, ways.size, rels.size].sum
    bar.increment!
  end
  puts('Collecting nodes')
  bar.max = node_count
  bar.count = 0
  
  collect_tagged(pbf, bar)
end

def persist_map(address_map)
  sio = StringIO.new(RapidJSON.dump(address_map))
  puts('Dumping JSON')
  bar = ProgressBar.new(sio.size)
  File.delete(MAP_PATH) if File.exist?(MAP_PATH)
  output = File.open(MAP_PATH, 'w') do |file|
    sio.each_char do |char|
      file << char
      bar.increment!
    end
  end
  output.close
end

def load_map
  input = File.open(MAP_PATH)
  RapidJSON.parse(input.read)
rescue StandardError => e
  puts 'Failed to parse address map, try regenerating the JSON using `-o` or deleting the file.'
  p e
end

if ARGV.include?('-o') || !File.file?(MAP_PATH)
  @address_map = generate_map
  persist_map(@address_map)
else
  @address_map = load_map unless @address_map
end

@maps = [
  @address_map,
  @address_map.values
].flatten

binding.pry

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
