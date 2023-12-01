#!/bin/bash
cid=$(docker run -d $1)
docker export $cid | sqfstar -comp zstd app.squashfs
docker rm -f $cid
cat template.sh app.squashfs > app.run
rm app.squashfs