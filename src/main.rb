require 'benchmark'
require 'pry'
require 'rapidjson'
require 'progress_bar'
require 'stringex'

MAP_PATH = 'data/generated/address-map.json'

@address_map = nil
@bar = nil
@count = 0
@files = []

def normalize(str)
  str
    .downcase
    .to_ascii
    .bytes
    .filter { |b| b <= 0x7a && b >= 0x61 || b <= 0x39 && b >= 0x30 || b == 0x20 }
    .map { |b| b.chr(Encoding::UTF_8) }
    .join('')
end

def deconstruct(str)
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

def digest(file)
  prefixes = parse_prefixes(file.path)

  file.each do |line|
    raw_address = JSON.parse(line)['properties']
    address = raw_address.transform_values { |value| normalize(value) }
    address.merge('country' => prefixes.first)
    address.merge('region' => prefixes[1]) if address['region'].empty?
    address.merge('city' => prefixes.last) if address['city'].empty?

    street, number, unit = address.values_at('street', 'number', 'unit')
    street = deconstruct(street)
    path = [*prefixes, *street, number, unit].reject(&:empty?)

    deep_set(path, @address_map, raw_address)
  rescue StandardError => e
    # puts e
    # puts path
    # puts line
  ensure
    @bar.increment!(line.size)
  end
end

def find_files(path)
  Dir
    .entries(path)
    .reject { |entry| entry.start_with?('.') }
    .each do |entry|
      full_entry = "#{path}/#{entry}"
      if File.directory?(full_entry)
        find_files(full_entry)
      elsif File.file?(full_entry)
        next if full_entry.match(/(\.meta|-parcels|-buildings)/)

        @files << File.open(full_entry)
      end
    end

  @files
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

  address_found = maps.find { |map| map['hash'] }
  return find_unit(address_ary, address_found) if address_found

  next_maps = address_ary
              .map { |part| maps.map { |map| map[part] || part } }
              .flatten
              .reject { |part| part.is_a?(String) }

  find_address(address_ary, next_maps)
end

def generate_map
  find_files('data/geojson')
  @files = @files.reject { |file| !file.path.match(/victoria/) }
  @count = count_rows(@files)
  puts('Generating address map')
  @bar = ProgressBar.new(@count)
  @address_map = {}
  @files.each { |file| digest(file) }

  sio = StringIO.new(RapidJSON.dump(@address_map))
  puts('Dumping JSON')
  @bar = ProgressBar.new(sio.size)
  File.delete(MAP_PATH) if File.exist?(MAP_PATH)
  output = File.open(MAP_PATH, 'w') do |file|
    sio.each_char do |char|
      file << char
      @bar.increment!
    end
  end
  output.close
end

def load_map
  input = File.open(MAP_PATH)
  @address_map = RapidJSON.parse(input.read)
rescue StandardError => e
  puts 'Failed to parse address map, try regenerating the JSON using `-o` or deleting the file.'
  p e
end

generate_map if ARGV.include?('-o') || !File.file?(MAP_PATH)
load_map unless @address_map

@maps = [
  @address_map,
  @address_map.values
].flatten

while true
  puts ''
  print 'address> '
  address = $stdin.gets.strip
  parsed = nil

  puts(Benchmark.measure do
    parsed = find_address(deconstruct(address), @maps)
  end)

  p parsed
end
