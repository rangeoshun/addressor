``` sh
docker build -f docker/Dockerfile -t addressor .
```

``` sh
docker run --rm -i -t -v ./:/app -v ./docker/home:/root:Z -w /app -p 3000:3000 addressor /bin/bash
```

``` sh
bundle exec puma -p 3000
```
```

# TODO

- [ ] Reinstate geojson loading from history
- [ ] Normalize countries to country codes
- [ ] Normalize street types or try to ignore them if possible
- [ ] Optimize JSONs by eliminating layers with single keys
- [ ] Unfold compound house numbers
