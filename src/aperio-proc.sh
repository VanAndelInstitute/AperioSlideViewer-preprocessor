#!/bin/bash -e

# NB: this script is for processing Aperio .SVS image files only

usage()
{
  echo "Usage: $0 -f SVS_FILE -s SOURCE_BUCKET -d DEST_BUCKET -t DYNAMODB_TABLE"
  exit 2
}

while getopts 'f:s:d:t:?h' c
do
  case $c in
    f)   FILE=$OPTARG ;;
    s)   SRCBKT=$OPTARG ;;
    d)   DSTBKT=$OPTARG ;;
    t)   TABLE=$OPTARG ;;
    h|?) usage ;;
    *) echo "Unexpected option: $c"
       usage ;;
  esac
done

# require input args
if [[ -z "${FILE-}" || -z "${SRCBKT-}" || -z "${DSTBKT-}" || -z "${TABLE-}" ]]; then
  usage
fi

# get barcoded ID and image ID from Aperio image filename
if [[ $FILE =~ ^([-a-zA-Z0-9]+)_([0-9]+).svs$ ]]; then
  barcode=${BASH_REMATCH[1]}
  imageid=${BASH_REMATCH[2]}
else
  echo "filename format should be {barcode}_{imageid}.svs"
  exit 2
fi

set -x

# download Aperio image file from S3 image bucket
aws configure set default.s3.max_concurrent_requests 50
aws configure set default.s3.multipart_chunksize 40MB
date +%T.%3N

aws s3 cp s3://$SRCBKT/$FILE .
date +%T.%3N

# extract, parse to json, and upload metadata to Slide table
vipsheader -f image-description $FILE | parse_desc.pl > data.json
aws dynamodb put-item \
    --table-name $TABLE \
    --item file://data.json
aws dynamodb update-item \
    --table-name $TABLE \
    --key '{"ImageID":{"S":"'$imageid'"}}' \
    --update-expression "SET Barcode = :bc" \
    --expression-attribute-values '{":bc":{"S":"'$barcode'"}}'

set +x

# Extract label and thumbnail images and upload to S3 viewer bucket.
# OpenSlide is not used as it's no longer maintained.
mkdir $imageid
npages=`vipsheader -f n-pages $FILE`
for ((i=$npages-1;i>1;i--)); do
  desc=`vipsheader -f image-description $FILE[page=$i]`
  [[ $desc =~ "label" ]] && break
done

set -x

vips pngsave $FILE[page=1] $imageid/thumbnail.png
vips pngsave $FILE[page=$i] $imageid/label.png

# Generate image pyramids
date +%T.%3N
vips dzsave $FILE $imageid/DeepZoom --layout dz
date +%T.%3N
vips dzsave $FILE $imageid/IIIF --layout iiif
date +%T.%3N

# Upload extracted,generated images to $imageid folder
aws s3 cp --quiet --recursive $imageid/ s3://$DSTBKT/$imageid
date +%T.%3N