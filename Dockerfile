# Build vips
FROM amazonlinux:2 as builder
RUN yum update -y
RUN yum groupinstall -y "Development Tools"
RUN yum install -y wget pkgconfig glib2-devel gtk-doc libxml2-devel
ENV GSFVERSION 1_14_47
RUN \
  # Build libgsf
  cd /tmp && \
  wget https://gitlab.gnome.org/GNOME/libgsf/-/archive/LIBGSF_${GSFVERSION}/libgsf-LIBGSF_${GSFVERSION}.tar.gz && \
  tar zxvf libgsf-LIBGSF_${GSFVERSION}.tar.gz && \
  cd /tmp/libgsf-LIBGSF_${GSFVERSION} && \
  ./autogen.sh && \
  make && \
  make install

RUN yum install -y unzip glib2-devel expat-devel gobject-introspection-devel libtiff-devel libjpeg-turbo-devel libexif-devel lcms2-devel
#ENV VIPSVERSION 8.10.0
ENV PKG_CONFIG_PATH /usr/local/lib/pkgconfig/
RUN \
  # Build libvips
  cd /tmp && \
  #wget https://github.com/libvips/libvips/releases/download/v${VIPSVERSION}-rc1/vips-${VIPSVERSION}-rc1.tar.gz && \
  wget https://github.com/kleisauke/libvips/archive/threadpool-reuse.zip && \
  #tar zxvf vips-${VIPSVERSION}-rc1.tar.gz && \
  unzip threadpool-reuse.zip && \
  #cd /tmp/vips-${VIPSVERSION} && \
  cd /tmp/libvips-threadpool-reuse && \
  #./configure --enable-debug=no --without-python --enable-deprecated=no && \
  ./autogen.sh --enable-debug=no --without-python --enable-deprecated=no && \
  make && \
  make install

RUN ldconfig /

# Add (to) aws-cli
FROM amazon/aws-cli
RUN yum update -y \
  && yum install -y less groff glib2 expat libtiff libjpeg-turbo libexif lcms2 perl \
  && yum clean all
COPY --from=builder /usr/local/bin/vips /usr/local/bin/
COPY --from=builder /usr/local/bin/vipsheader /usr/local/bin/
COPY --from=builder /usr/local/bin/vipsprofile /usr/local/bin/
COPY --from=builder /usr/local/lib/libvips.so.42 /usr/local/lib
COPY --from=builder /usr/local/lib/libgsf-1.so.114 /usr/local/lib
RUN cd /usr/local/lib && ln -s libvips.so.42 libvips.so && ln -s libgsf-1.so.114 libgsf-1.so
COPY src/ /usr/local/bin/

WORKDIR /aws
ENTRYPOINT [ "aperio-proc.sh" ]
#CMD [ "-f barcode_imageid.svs", "-s source-bucket", "-d dest-bucket", "-t dynamodb-table-name" ]