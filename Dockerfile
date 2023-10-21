FROM ubuntu
RUN apt-get update && apt-get upgrade && \
    apt install -y \ 
    curl \
    xz-utils \
    git \
    wget

ARG ZIG_VERSION=0.12.0-dev.1137+fbbccc9d5
ARG ZIG_DEV=zig-linux-x86_64-${ZIG_VERSION}
ARG ZIG_RELEASE=zig-linux-x86_64-${ZIG_VERSION}.tar.xz
ARG ZIG_URL=https://ziglang.org/builds/${ZIG_RELEASE}
ARG ZIG_DEST=/usr/local/bin/zig
WORKDIR /usr/src
RUN wget ${ZIG_URL}
RUN tar -xvf ${ZIG_RELEASE}
ENV PATH="${PATH}:/usr/src/${ZIG_DEV}"
WORKDIR /app
RUN git clone https://github.com/braxpark/BMWB
WORKDIR /app/BMWB
EXPOSE 3000
RUN echo $(pwd)
CMD ["zig", "build", "run"]
