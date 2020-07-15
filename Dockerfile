# Only Debian seems to have the latest vips-tools build with openslide
FROM debian:bullseye-slim

RUN apt-get -qq update && apt-get -qq upgrade && apt-get -qq install \
    curl \
    groff \
    less \
    unzip \
    libvips-tools

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \ 
    && unzip awscliv2.zip \
    && ./aws/install

RUN useradd -ms /bin/bash svcuser
USER svcuser
WORKDIR /home/svcuser
COPY src/* ./
ENTRYPOINT [ "./proc-aperio.sh" ]