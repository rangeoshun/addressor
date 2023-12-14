# Addressor

An address validator service.

## Concept

Keep it in the memory. Produce a map of addresses like the following:

``` ruby
{
  "hu" => {
    "budapest": {
      "1085": {
        "jozsef": {
          "korut": {
            "16": {
              "city"=> "Budapest", 
              "state"=>nil,
              "county"=>nil,
              "region"=>nil,
              "postcode"=>"1085",
              "street"=>"József körút",
              "number"=>"16",
              "unit"=>nil
            }
          }
        }
      }
    }
  }
}
```

Recieve an input: `Budapest, József korut 16, 1085`

Normalize it to something like this: 

``` ruby
["budapest", "jozsef", "korut", "16", "1085"]
```

Then recursively iterate over each and try to navigate down each map received in each iteration. Finally you should end up with an address hash.

## Missing country codes

To handle missing contry codes, the easiest way to store a map without the country code as a separate map in the map list.

## Data

Currently it handles `osm.pbf`, but `geojson` will also be added. Just copy your `pbf` into `data/osm/[country_code]/my.osm.pbf`.

## Instructions

``` sh
docker build -f docker/Dockerfile -t addressor .
```

``` sh
docker run --rm -i -t -v ./:/app -v ./docker/home:/root:Z -w /app -p 3000:3000 addressor /bin/bash
```

``` sh
bundle exec puma -p 3000
```

# TODO

- [ ] Reinstate geojson loading from history
- [ ] Normalize countries to country codes
- [ ] Normalize street types or try to ignore them if possible
- [ ] Optimize JSONs by eliminating layers with single keys
- [ ] Unfold compound house numbers
