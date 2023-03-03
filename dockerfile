FROM --platform=linux/386 ubuntu:14.04

# (Option) Use opentuna source to accelerate
RUN sed -i 's/archive.ubuntu.com/opentuna.cn/g' /etc/apt/sources.list
# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential libncurses5-dev && \ 
    rm -rf /var/lib/apt/lists/*

WORKDIR /src
ENTRYPOINT [ "make", "-j" ]
CMD ["help"]
