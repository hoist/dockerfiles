#!/bin/bash

set -e;
echo "getting settings";
etcdctl updatedir /mongo/replica/nodes/$COREOS_PRIVATE_IPV4 --ttl 300 2>/dev/null || true;
echo "updated dir 1";
etcdctl setdir /mongo/replica/nodes/$COREOS_PRIVATE_IPV4 --ttl 300 2>/dev/null || true;
echo "updated dir 2";
etcdctl set /mongo/replica/nodes/$COREOS_PRIVATE_IPV4/port 27017;
echo "saved node port";
etcdctl set /mongo/replica/nodes/$COREOS_PRIVATE_IPV4/status on;
echo "saved node status";
CONFIGURATION_NODE=$(etcdctl get /mongo/replica/configure 2>/dev/null ||  /usr/bin/etcdctl set /mongo/replica/configure $COREOS_PRIVATE_IPV4 --ttl 60);
echo "CONFIGURATION_NODE is $CONFIGURATION_NODE";
if [ "$CONFIGURATION_NODE" == "$COREOS_PRIVATE_IPV4" ];
then
	CHECK_MONGO=$(/usr/bin/docker ps | grep mongodb);
	echo "this is the correct node to configure";
else
	echo "this is not the configuration node";
	sleep 60;
	exit 0;
fi;
CONFIGURATION_STEP=$(etcdctl get /mongo/replica/configure_step 2>/dev/null || true);
SITE_ROOT_PWD=$(etcdctl get /mongo/replica/siteRootAdmin/pwd 2>/dev/null || etcdctl set /mongo/replica/siteRootAdmin/pwd $(openssl rand -base64 32));
SITE_USR_ADMIN_PWD=$(etcdctl get /mongo/replica/siteUserAdmin/pwd 2>/dev/null || etcdctl set /mongo/replica/siteUserAdmin/pwd $(openssl rand -base64 32));
if [ -z "$CONFIGURATION_STEP" ];
then
	echo "ensuring 10 minutes to continue setup";
	/usr/bin/etcdctl set /mongo/replica/configure $COREOS_PRIVATE_IPV4 --ttl 600;
	echo "Creating the siteUserAdmin... ";
	docker run -t --rm mongo:3.0 mongo $COREOS_PRIVATE_IPV4/admin --eval "db.createUser({user:'siteUserAdmin', pwd:'$SITE_USR_ADMIN_PWD',roles: [{role:'userAdminAnyDatabase', db:'admin'}, 'readWrite' ]});";
	echo "Creating the siteRootAdmin... ";
	docker run -t --rm mongo:3.0 mongo $COREOS_PRIVATE_IPV4/admin --eval "db.createUser({user:'siteRootAdmin', pwd:'$SITE_ROOT_PWD',roles: [{role:'root', db:'admin'}, 'readWrite' ]});";
	echo "writing the replica key";
	etcdctl set /mongo/replica/key $(openssl rand -base64 741);
	CONFIGURATION_STEP=$(etcdctl set /mongo/replica/configure_step "REPLICASET");
	etcdctl set /mongo/replica/configured_by $COREOS_PRIVATE_IPV4;
	systemctl restart mongo.service;
	
	#give mongo time to restart
	sleep 60;
fi;
if [ "$CONFIGURATION_STEP" == "REPLICASET" ];
then
	echo 'creating replica set';
	docker run -t --rm mongo mongo $COREOS_PRIVATE_IPV4/admin -u siteRootAdmin -p $SITE_ROOT_PWD --eval 'rs.initiate();'; 
	CONFIGURATION_STEP=$(etcdctl set /mongo/replica/configure_step "DONE");
	/usr/bin/etcdctl set /mongo/replica/configure $COREOS_PRIVATE_IPV4 --ttl 60;
fi;
echo "configuration step: $CONFIGURATION_STEP";
echo "adding nodes";
PRIMARY=$(docker run --rm mongo mongo $COREOS_PRIVATE_IPV4/admin -u siteRootAdmin -p $SITE_ROOT_PWD --quiet --eval "db.isMaster()['primary']";);
PRIMARY=${PRIMARY/:27017/};
echo "master: $PRIMARY"
echo "hostname: $HOSTNAME"
if [ "$PRIMARY" == "$COREOS_PRIVATE_IPV4" ] || [ "$PRIMARY" == "$HOSTNAME" ];
then
	ADD_CMDS=$(etcdctl ls /mongo/replica/nodes | grep -v "$COREOS_PRIVATE_IPV4" | xargs -I{} basename {} | xargs -I{} echo "rs.add('{}:27017');");
	echo "add command: $ADD_CMDS";
	(docker run -t --rm mongo mongo $COREOS_PRIVATE_IPV4/admin -u siteRootAdmin -p $SITE_ROOT_PWD --quiet --eval "var config = rs.config(); if (config.members.length === 1) { config.members[0].host = '$COREOS_PRIVATE_IPV4'; rs.reconfig(config); }")>/dev/null || true; 
	(docker run -t --rm mongo mongo $COREOS_PRIVATE_IPV4/admin -u siteRootAdmin -p $SITE_ROOT_PWD --quiet --eval "$ADD_CMDS";) >/dev/null || true; 
	echo "creating users for applications";
	EXISTING_USER_OVERLORD=$((docker run -t --rm mongo mongo $COREOS_PRIVATE_IPV4/hoist-overlord -u siteRootAdmin -p $SITE_ROOT_PWD --authenticationDatabase admin --quiet --eval "printjson(db.getUsers())") | grep hoist-overlord || true);
	if [ -z "$EXISTING_USER_OVERLORD" ];
	then
		echo "creating overlord user";
		ADD_OVERLORD_CMD=$(echo "db.createUser({ user: 'hoist-overlord', pwd: 'HK^afHKhyPnabFuHyLk(dCFVnT9a7raya', roles: [{ role: 'readWrite', db: 'hoist-overlord' }]});");
		echo "$ADD_OVERLORD_CMD";
		docker run -t --rm mongo mongo $COREOS_PRIVATE_IPV4/hoist-overlord -u siteRootAdmin -p $SITE_ROOT_PWD --authenticationDatabase admin --quiet --eval "$ADD_OVERLORD_CMD";
	else
		echo "hoist-overlord user already exists";
	fi;
	
	EXISTING_USER_HOIST=$((docker run -t --rm mongo mongo $COREOS_PRIVATE_IPV4/hoist-connect -u siteRootAdmin -p $SITE_ROOT_PWD --authenticationDatabase admin --quiet --eval "printjson(db.getUsers())") | grep hoist-connect || true);
	if [ -z "$EXISTING_USER_HOIST" ];
	then
		echo "creating hoist-connect user";
		ADD_HOIST_CMD=$(echo "db.createUser({ user: 'hoist-connect', pwd: 'FGdp6MUXC^Nq9uYJCruvq', roles: [{ role: 'readWrite', db: 'hoist-connect' }, {role:'userAdmin', db:'admin'}]});");
		echo "$ADD_HOIST_CMD";
		docker run -t --rm mongo mongo $COREOS_PRIVATE_IPV4/hoist-connect -u siteRootAdmin -p $SITE_ROOT_PWD --authenticationDatabase admin --quiet --eval "$ADD_HOIST_CMD";
	else
		echo "hoist-connect user already exists";
	fi;

else
	/usr/bin/etcdctl set /mongo/replica/configure $PRIMARY --ttl 300;
	echo "not the primary node";
	exit 1;
fi;
echo "done";