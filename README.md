# SVS preprocessor for Virtual Slide Viewer
Program that makes image pyramids from Aperio SVS files stored in Amazon S3. Also extracts metadata, label image, and thumbnail.

OpenSlide [must be used to properly open SVS files](https://github.com/libvips/libvips/issues/1492#issuecomment-662007128).

## General Aperio Slide Viewer workflow
1. Scanner dumps files onto ScanScope Workstation 
2. aws s3 sync from ScanScope Workstation to images S3 bucket
    - delete local files on successful sync
3. **image preprocessor runs:**
    - extract thumbnail and label image
    - decode slide ID in 2D barcode
    - extract metadata and put into DynamoDB slide table
    - generate Deep Zoom and IIIF views
    - upload into viewer S3 bucket
4.	scan tech reviews images for scanning errors
    - searches for new (unsent) slides
    - deletes and rescans failed slide scans
    - fixes slide/case IDs, if incorrect or missing
    - marks slides to send (metadata) to CDR
5.	pathologist review

## Usage
```
$ alias aperio-proc='docker run --rm -ti -v ~/.aws:/root/.aws vanandelinstitute/aperio-proc'
$ aperio-proc -f "imageid.svs" -s "source-bucket" -d "dest-bucket" -t "dynamodb-table-name"
```
