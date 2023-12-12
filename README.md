``` sh
docker build -f docker/Dockerfile -t addressor .
```

``` sh
docker run --rm -i -t -v ./:/app -w /app addressor /bin/bash
```
