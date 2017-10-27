FROM ubuntu:xenial-20171006

RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys "D401AB61 DBE1D0A2" && \
    echo "deb http://dl.bintray.com/pony-language/ponyc-debian pony-language main" >> /etc/apt/sources.list && \
    echo "deb http://dl.bintray.com/pony-language/pony-stable-debian /" >> /etc/apt/sources.list && \
    apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
# libraries and build tools
    git \
    ponyc \
    pony-stable \
    build-essential \
    libsnappy-dev \
    liblz4-dev \
    libssl-dev \
# useful tools/utilities
    man \
    netcat \
    curl \
    wget \
    less \
    dnsutils \
    net-tools \
    vim \
    sysstat \
    htop \
    numactl \
# python
    python-dev \
    python-pip && \
    pip install virtualenv virtualenvwrapper && \
    pip install --upgrade pip && \
# cleanup
    rm -rf /var/lib/apt/lists/* && \     
    apt-get -y autoremove --purge && \
    apt-get -y clean

COPY book /wallaroo/book/
COPY book.json /wallaroo/
COPY CHANGELOG.md /wallaroo/
COPY CODE_OF_CONDUCT.md /wallaroo/
COPY CONTRIBUTING.md /wallaroo/
COPY cover.jpg /wallaroo/
COPY cpp_api /wallaroo/cpp_api/
COPY Dockerfile /wallaroo/
COPY examples /wallaroo/examples/
COPY giles /wallaroo/giles/
COPY intro.md /wallaroo/
COPY lib /wallaroo/lib/
COPY LICENSE.md /wallaroo/
COPY LIMITATIONS.md /wallaroo/
COPY machida /wallaroo/machida/
COPY Makefile /wallaroo/
COPY monitoring_hub /wallaroo/monitoring_hub/
COPY orchestration /wallaroo/orchesration/
COPY README.md /wallaroo/
COPY ROADMAP.md /wallaroo/
COPY rules.mk /wallaroo/
COPY SUMMARY.md /wallaroo/
COPY SUPPORT.md /wallaroo/
COPY utils /wallaroo/utils/

WORKDIR /wallaroo
RUN make clean && \
    make build-giles-all && \
    make build-utils-all && \
    make build-machida-all && \
    mkdir /wallaroo-bin && \
    cp giles/sender/sender /wallaroo-bin/sender && \
    cp giles/receiver/receiver /wallaroo-bin/receiver && \
    cp machida/build/machida /wallaroo-bin/machida && \
    cp utils/cluster_shutdown/cluster_shutdown /wallaroo-bin/cluster_shutdown && \
    make clean


ENV PATH /wallaroo-bin:$PATH
ENV PYTHONPATH /wallaroo/machida:$PYTHONPATH

ENTRYPOINT ["bash"]

