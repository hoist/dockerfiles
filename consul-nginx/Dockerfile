FROM gliderlabs/alpine
MAINTAINER Hoist Apps Ltd <support@hoist.io>

ENV DOCKER_VERSION 1.7.1 

ADD https://releases.hashicorp.com/consul-template/0.11.1/consul-template_0.11.1_linux_amd64.tar.gz /tmp/consul-template.tgz

RUN cd /bin && gzip -dc /tmp/consul-template.tgz | tar -xf - && rm /tmp/consul-template.tgz && mv /bin/consul-template_0.11.1_linux_amd64/consul-template /bin/consul-template && rmdir /bin/consul-template_0.11.1_linux_amd64

ADD https://get.docker.com/builds/Linux/x86_64/docker-${DOCKER_VERSION} /bin/docker

RUN chmod +x /bin/docker

RUN apk --update add curl bash

ENV DOCKER_HOST unix:///tmp/docker.sock

ADD hoist.conf /templates/hoist.conf
ADD consul-template.config /templates/consul-template.config

ENV CONSUL_HTTP_ADDR consul.service.consul:8500
ENV NGINX nginx

ENTRYPOINT ["/bin/consul-template","-config","/templates/consul-template.config"]