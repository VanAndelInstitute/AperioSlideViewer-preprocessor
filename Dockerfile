# Build vips
FROM amazonlinux:2 as installer
RUN yum update -y
RUN yum groupinstall -y "Development Tools"
RUN yum install -y wget pkgconfig glib2-devel expat-devel libtiff-devel libjpeg-turbo-devel libexif-devel lcms2-devel libpng-devel libgsf-devel

ENV VIPSVERSION 8.10.0
RUN \
  # Build libvips
  cd /tmp && \
  wget https://github.com/libvips/libvips/releases/download/v$VIPSVERSION-rc1/vips-$VIPSVERSION-rc1.tar.gz && \
  tar zxvf vips-$VIPSVERSION-rc1.tar.gz && \
  cd /tmp/vips-$VIPSVERSION && \
  ./configure --enable-debug=no --without-python --enable-deprecated=no && \
  make && \
  make install DESTDIR=/vips

RUN ldconfig /

# Add (to) aws-cli
FROM amazon/aws-cli
RUN yum update -y \
  && yum install -y less groff glib2 expat libtiff libjpeg-turbo libexif lcms2 libpng libgsf perl \
  && yum clean all
COPY --from=installer /vips/usr/local/bin/vips /usr/local/bin/
COPY --from=installer /vips/usr/local/bin/vipsheader /usr/local/bin/
COPY --from=installer /vips/usr/local/lib/libvips.so.42 /usr/local/lib

COPY src/ /usr/local/bin/
# Use /tmp for extra security
WORKDIR /tmp
ENTRYPOINT [ "aperio-proc.sh" ]
#CMD [ "-f barcode_imageid.svs", "-s source-bucket", "-d dest-bucket", "-t dynamodb-table-name" ]