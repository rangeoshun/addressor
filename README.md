``` sh
docker build -f docker/Dockerfile -t addressor .
```

``` sh
docker run --rm -i -t -v ./:/app -v ./docker/home:/root:Z -w /app addressor /bin/bash
```
