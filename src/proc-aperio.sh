#!/bin/bash -x

# NB: this script is for processing Aperio .SVS image files only

usage()
{
  echo "Usage: proc-aperio NAMED_ARGS
  Where NAMED_ARGS are:
    --file, -f      FILENAME
    --source, -s    BUCKET
    --dest, -d      BUCKET
    --table, t      TABLE"
  exit 2
}

PARSED_ARGUMENTS=$(getopt -a -n proc-aperio -o f:s:d:t: --long file:,source:,dest:,table: -- "$@")
VALID_ARGUMENTS=$?
if [ "$VALID_ARGUMENTS" != "0" ]; then
  usage
fi

echo "PARSED_ARGUMENTS is $PARSED_ARGUMENTS"
eval set -- "$PARSED_ARGUMENTS"
while :
do
  case "$1" in
    -f | --file)    FILE="$2"    ; shift 2 ;;
    -s | --source)  SRCBKT="$2"  ; shift 2 ;;
    -d | --dest)    DSTBKT="$2"  ; shift 2 ;;
    -t | --table)   TABLE="$2"   ; shift 2 ;;
    # -- means the end of the arguments; drop this, and break out of the while loop
    --) shift; break ;;
    # If invalid options were passed, then getopt should have reported an error,
    # which we checked as VALID_ARGUMENTS when getopt was called...
    *) echo "Unexpected option: $1 - this should not happen."
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

# download Aperio image file from S3 image bucket
aws s3 cp s3://$SRCBKT/$FILE .

# extract, parse to json, and upload metadata to Slide table
vipsheader -f tiff.ImageDescription $FILE|./parse.pl > data.json
aws dynamodb put-item \
    --table-name $TABLE \
    --item file://data.json
aws dynamodb update-item \
    --table-name $TABLE \
    --key '{"ImageID":{"S":"'$imageid'"}}' \
    --update-expression "SET Barcode = :bc" \
    --expression-attribute-values '{":bc":{"S":"'$barcode'"}}'

# extract label and thumbnail images and upload to S3 viewer bucket
vips openslideload --associated label $FILE label.png
vips openslideload --associated thumbnail $FILE thumbnail.png
aws s3 cp label.png s3://$DSTBKT/$imageid/label.png
aws s3 cp thumbnail.png s3://$DSTBKT/$imageid/thumbnail.png

#TODO: generate image pyramids
#vips dzsave ../$imgfile DeepZoom --layout dz
#vips dzsave ../$imgfile IIIF --layout iiif
#aws s3 cp DeepZoom.dzi s3://DST_BUCKET/$imageid/DeepZoom.dzi
#aws s3 cp DeepZoom_files/ s3://DST_BUCKET/$imageid/DeepZoom_files/
#aws s3 cp IIIF s3://DST_BUCKET/$imageid/IIIF