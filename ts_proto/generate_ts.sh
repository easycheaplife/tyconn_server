#!/bin/bash
find ../proto -name "*.proto" -exec protoc \
  --proto_path=../proto \
  --plugin="./node_modules/.bin/protoc-gen-ts_proto" \
  --ts_proto_out=. \
  --ts_proto_opt=forceLong=bigint \
  --ts_proto_opt=useOptionals=messages \
  --ts_proto_opt=esModuleInterop=true \
  --ts_proto_opt=outputJsonMethods=false \
  --ts_proto_opt=outputEncodeMethods=false \
  --ts_proto_opt=outputPartialMethods=false \
  --ts_proto_opt=outputTypeAnnotations=true \
  {} \;
