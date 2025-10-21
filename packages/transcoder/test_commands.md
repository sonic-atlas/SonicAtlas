# Commands to test transcoding

## With script

### For testing each request sequentially

```text
chmod +x test_speed.sh
./test_speed.sh 
```

## For testing all at once

```
./test_speed.sh --concurrent
```


## High-Res file (at least 48kHz or 24-bit)

```text
curl -X POST "http://localhost:8000/transcode/hi-res-test" \
     -H "Content-Type: application/json" \
     -d '{"quality": "high"}'
```

```text
curl -X POST "http://localhost:8000/transcode/hi-res-test" \
     -H "Content-Type: application/json" \
     -d '{"quality": "efficiency"}'
```

```text
curl -X POST "http://localhost:8000/transcode/hi-res-test" \
     -H "Content-Type: application/json" \
     -d '{"quality": "cd"}'
```
## CD file (usually 44.1kHz and 16-bit)

```text
curl -X POST "http://localhost:8000/transcode/cd-test" \
     -H "Content-Type: application/json" \
     -d '{"quality": "high"}'
```

```text
curl -X POST "http://localhost:8000/transcode/cd-test" \
     -H "Content-Type: application/json" \
     -d '{"quality": "efficiency"}'
```