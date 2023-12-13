``` sh
docker build -f docker/Dockerfile -t addressor .
```

``` sh
docker run --rm -i -t -v ./:/app -v ./docker/home:/root:Z -w /app addressor /bin/bash
```

``` sh
ruby src/main.rb
```

``` sh
ruby src/main.rb -o
```

# TODO

- [ ] Reinstate geojson loading from history
- [ ] Normalize countries to country codes
- [ ] Normalize street types
