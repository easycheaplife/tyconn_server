#!/bin/bash
find ../proto -name "*.proto" -exec protoc \
  --proto_path=../proto \
  --plugin="./node_modules/.bin/protoc-gen-ts_proto" \
  --ts_proto_out=. \
  --ts_proto_opt=forceLong=bigint \
  {} \;
