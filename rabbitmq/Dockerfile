FROM ubuntu:trusty

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -r rabbitmq && useradd -r -d /var/lib/rabbitmq -m -g rabbitmq rabbitmq

RUN DEBIAN_FRONTEND=noninteractive apt-get install wget -y

# Install RabbitMQ.
RUN \
  wget -qO - http://www.rabbitmq.com/rabbitmq-signing-key-public.asc | apt-key add - && \
  echo "deb http://www.rabbitmq.com/debian/ testing main" > /etc/apt/sources.list.d/rabbitmq.list && \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y rabbitmq-server && \
  apt-get clean && \
  rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/* && \
  rabbitmq-plugins enable rabbitmq_mqtt rabbitmq_stomp rabbitmq_management  rabbitmq_management_agent rabbitmq_management_visualiser rabbitmq_federation rabbitmq_federation_management sockjs && \
  echo "[{rabbit, [{loopback_users, []}]}]." > /etc/rabbitmq/rabbitmq.config

ADD startrabbit.sh /opt/rabbit/
ADD set_rabbitmq_password.sh /opt/rabbit/set_rabbitmq_password.sh
RUN chmod a+x /opt/rabbit/*.sh

EXPOSE 5672
EXPOSE 15672
EXPOSE 25672
EXPOSE 4369
EXPOSE 9100
EXPOSE 9101
EXPOSE 9102
EXPOSE 9103
EXPOSE 9104
EXPOSE 9105



ENTRYPOINT ["/opt/rabbit/startrabbit.sh"]