FROM debian:jessie

ADD . /app/src/github.com/die-net/fotomat

ENTRYPOINT ["/app/bin/fotomat"]

CMD ["-listen=:3520"]

EXPOSE 3520

RUN \
    # Apply updates and install our dependencies
    apt-get -q update && \
    apt-get -y -q dist-upgrade && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends \
       ca-certificates curl \
       git automake build-essential libglib2.0-dev libjpeg-dev libpng12-dev \
       libwebp-dev libtiff5-dev libexif-dev libmagickwand-dev && \

    # Create a few directories
    mkdir -p /usr/local/go /usr/local/vips /app/pkg /app/bin && \

    # Fetch and install Go
    curl -sS https://storage.googleapis.com/golang/go1.6.linux-amd64.tar.gz | \
        tar --strip-components=1 -C /usr/local/go -xzf - && \

    # Fetch and build VIPS (enabling GCC's auto-vectorization)
    curl -sS http://www.vips.ecs.soton.ac.uk/supported/8.2/vips-8.2.2.tar.gz | \
        tar --strip-components=1 -C /usr/local/vips -xzf - && \
    cd /usr/local/vips && \
    CFLAGS="-O2 -ftree-vectorize -msse4.2 -ffast-math" CXXFLAGS="-O2 -ftree-vectorize -msse4.2 -ffast-math" \
        ./configure --disable-debug --disable-dependency-tracking --disable-gtk-doc-html --disable-pyvips8 --disable-static \
        --with-OpenEXR --with-jpeg --with-lcms --with-libexif --with-magick --with-tiff --with-libwebp --with-png \
        --without-cfitsio --without-fftw --without-gsf --without-matio --without-openslide --without-orc \
        --without-pangoft2 --without-python --without-x --without-zip && \
    make && make install && ldconfig && \

    # Build, install, and test fotomat
    GOPATH=/app /usr/local/go/bin/go get -t github.com/die-net/fotomat/cmd/fotomat github.com/die-net/fotomat/thumbnail github.com/die-net/fotomat/format && \
    GOPATH=/app /usr/local/go/bin/go test -v github.com/die-net/fotomat/cmd/fotomat github.com/die-net/fotomat/thumbnail github.com/die-net/fotomat/format && \
    strip /app/bin/fotomat && \

    # Add a fotomat user for it to run as, and make filesystem read-only to that user.
    useradd -m fotomat -s /bin/bash && \
    find / -type d -perm +002 -print0 | xargs -0 chmod o-w && \

    # Mark fotomat's dependencies as needed, to avoid autoremoval
    ldd /app/bin/fotomat | awk '($2=="=>"&&substr($3,1,11)!="/usr/local/"){print $3}' | \
        xargs dpkg -S | cut -d: -f1 | sort -u | xargs apt-get install && \

    # And remove almost everything else that we installed
    apt-get remove -y git automake build-essential libglib2.0-dev libjpeg-dev libpng12-dev \
       libwebp-dev libtiff5-dev libexif-dev libmagickwand-dev && \
    apt-get autoremove -y && \
    apt-get autoclean && \
    apt-get clean && \
    rm -rf /usr/local/go /usr/local/vips /app/pkg /var/lib/apt/lists/*

# Start by default as a non-root user.
USER fotomat
