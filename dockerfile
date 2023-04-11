FROM registry.cn-hangzhou.aliyuncs.com/jklincn/ubuntu:14.04-386

# (Option) Use opentuna source to accelerate
RUN sed -i 's/archive.ubuntu.com/mirrors.ustc.edu.cn/g' /etc/apt/sources.list
# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential libncurses5-dev automake pkg-config && \ 
    rm -rf /var/lib/apt/lists/*

WORKDIR /src
ENTRYPOINT [ "make", "-j" ]
CMD ["help"]
