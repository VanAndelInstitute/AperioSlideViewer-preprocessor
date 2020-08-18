#!/bin/bash -e
date +%T

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
# if [[ $FILE =~ ^([-a-zA-Z0-9 ]+)_([0-9]+).svs$ ]]; then
#   barcode=${BASH_REMATCH[1]}
#   imageid=${BASH_REMATCH[2]}
# else
#   echo "filename format should be {barcode}_{imageid}.svs"
#   exit 2
# fi

# set -x
# echo $barcode
# echo $imageid

# download Aperio image file from S3 image bucket
aws configure set default.s3.max_concurrent_requests 50
aws configure set default.s3.multipart_chunksize 40MB
time aws s3 cp "s3://$SRCBKT/${FILE}" .

# get image id from tiff tags; create output folder
imageid=$(vipsheader -f aperio.ImageID ${FILE})
mkdir -p $imageid

# Extract label and thumbnail images
vips openslideload --associated thumbnail "${FILE}" $imageid/thumbnail.jpg
vips openslideload --associated label "${FILE}" $imageid/label.jpg

# decode slide id from 2D barcode in label image
slideid=$(dmtxread -N1 $imageid/label.jpg)
# guess at case id
caseid=${slideid%-*}

tiff_tags_to_json () {
  while read line;
  do
    line="${line//aperio\./}";
    key="${line%:\ *}";
    value="${line#*:\ }";
    [ "${key}" = "Date" ] && value=$(date -d ${value} +'%Y/%m/%d');
    echo "  \"${key// /}\": {\"S\": \"${value}\"},";
  done
}

# extract fields and parse to json
tags=$(vipsheader -a "${FILE}" | grep "^aperio\.")
json=$(tiff_tags_to_json <<< "$tags")
json="${json}\n  \"SlideID\": {\"S\": \"${slideid}\"},"
json="${json}\n  \"CaseID\": {\"S\": \"${caseid}\"}"
printf "{\n$json\n}\n" > data.json

# upload parsed metadata to Slide table
aws dynamodb put-item \
    --table-name $TABLE \
    --item file://data.json

# Generate image pyramids
time vips dzsave "${FILE}" $imageid/DeepZoom --layout dz &
time vips dzsave "${FILE}" $imageid/IIIF --layout iiif --id="https://${DSTBKT}.s3.us-east-2.amazonaws.com/${imageid}/IIIF" &
wait
touch $imageid/processing.done

# Upload extracted,generated images to $imageid folder
time aws s3 sync $imageid/ s3://$DSTBKT/$imageid --only-show-errors
date +%T