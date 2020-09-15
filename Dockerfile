# Build vips
FROM amazonlinux:2 as builder
RUN yum update -y
RUN yum groupinstall -y "Development Tools"
WORKDIR /build

# Build libgsf
RUN yum install -y wget pkgconfig glib2-devel gtk-doc libxml2-devel
ENV GSFVERSION 1_14_47
RUN \
  wget https://gitlab.gnome.org/GNOME/libgsf/-/archive/LIBGSF_${GSFVERSION}/libgsf-LIBGSF_${GSFVERSION}.tar.gz && \
  tar zxvf libgsf-LIBGSF_${GSFVERSION}.tar.gz && \
  cd libgsf-LIBGSF_${GSFVERSION} && \
  ./autogen.sh && \
  make && \
  make install

# Build OpenSlide
RUN yum install -y libjpeg-turbo-devel openjpeg-devel libtiff-devel cairo-devel gdk-pixbuf2-devel sqlite-devel
ENV OSVERSION 3.4.1
RUN \
  wget https://github.com/openslide/openslide/releases/download/v${OSVERSION}/openslide-${OSVERSION}.tar.gz && \
  tar zxvf openslide-${OSVERSION}.tar.gz && \
  cd openslide-${OSVERSION} && \
  ./configure && \
  make && \
  make install
  
# Build libvips
RUN yum install -y unzip glib2-devel expat-devel gobject-introspection-devel libexif-devel lcms2-devel
ENV VIPSVERSION 8.10.0
ENV PKG_CONFIG_PATH /usr/local/lib/pkgconfig/
RUN \
  wget https://github.com/libvips/libvips/releases/download/v${VIPSVERSION}-rc1/vips-${VIPSVERSION}-rc1.tar.gz && \
  tar zxvf vips-${VIPSVERSION}-rc1.tar.gz && \
  cd vips-${VIPSVERSION} && \
  ./configure --with-gsf=yes --with-openslide=yes --enable-debug=no --without-python --enable-deprecated=no && \
  make && \
  make install

# Build libdmtx
ENV DMTXVERSION 0.7.5
RUN \
  wget https://github.com/dmtx/libdmtx/archive/v${DMTXVERSION}.tar.gz && \
  tar zxvf v${DMTXVERSION}.tar.gz && \
  cd libdmtx-${DMTXVERSION} && \
  ./autogen.sh && \
  ./configure && \
  make && \
  make install

# Build dmtx-utils
RUN yum install -y ImageMagick-devel
ENV DMTXUTILSVERSION 0.7.6
RUN \
  wget https://github.com/dmtx/dmtx-utils/archive/v${DMTXUTILSVERSION}.tar.gz && \
  tar zxvf v${DMTXUTILSVERSION}.tar.gz && \
  cd dmtx-utils-${DMTXUTILSVERSION} && \
  ./autogen.sh && \
  ./configure && \
  make && \
  make install
RUN ldconfig /

# Add (to) aws-cli
FROM amazon/aws-cli
RUN yum update -y \
  && yum install -y zip less groff glib2 expat libtiff libjpeg-turbo libexif lcms2 libpng cairo openjpeg-libs gdk-pixbuf2 ImageMagick \
  && yum clean all
COPY --from=builder /usr/local/bin/vips /usr/local/bin/
COPY --from=builder /usr/local/bin/vipsheader /usr/local/bin/
COPY --from=builder /usr/local/bin/vipsprofile /usr/local/bin/
COPY --from=builder /usr/local/bin/dmtxread /usr/local/bin/
COPY --from=builder /usr/local/lib/libvips.so.42 /usr/local/lib
COPY --from=builder /usr/local/lib/libgsf-1.so.114 /usr/local/lib
COPY --from=builder /usr/local/lib/libopenslide.so.0 /usr/local/lib
COPY --from=builder /usr/local/lib/libdmtx.so.0 /usr/local/lib
RUN cd /usr/local/lib && ln -s libvips.so.42 libvips.so && ln -s libgsf-1.so.114 libgsf-1.so && ln -s libopenslide.so.0 libopenslide.so
COPY src/ /usr/local/bin/

WORKDIR /aws
ENTRYPOINT [ "svs2vsv.sh" ]
#CMD [ "-f imageid.svs", "-s source-bucket", "-d dest-bucket", "-t dynamodb-table-name" ]