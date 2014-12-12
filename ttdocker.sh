#/bin/bash

function echo_help {
cat <<USAGE_END
Usage:
  ttdocker.sh ttlocal|ttdev|ttprod|tt... setup|start|stop|rm client|noclient [debug]

  Orchestrate your TapTinder containers for

  ttlocal ... local purpose
  ttdev ... TapTinder development purpose
  ttprod ... production purpose

  setup ... setup all containers
  start ... start all containers
  stop ... stop all containers
  rm ... remove all containers (delete all data)
  wbash ... start bash inside temporary web container

  client ... start also testing (tt-client container)
  no-client ... do not start tt-client container
  client-only ... do not start tt-server container

  debug ... run in debug mode

Example:
  ttdocker.sh ttlocal start client debug
  ttdocker.sh ttprod start noclient

USAGE_END
}

function container_exists {
	CONT_NAME="$1"
	set +e
	docker inspect $CONT_NAME &>/dev/null
	ECODE="$?"
	set -e
	#echo "Output: $ECODE"
	if [ "$ECODE" == 1 ]; then
		echo no
	else
		echo yes
	fi
}

if [ -z "$1" ]; then
    echo_help
    exit 1
fi

if [ "$1" == '--help' -o "$1" == '-h' ]; then
    echo_help
    exit
fi

CNAME_PREFIX="$1"
CMD="$2"
CLIENT_PAR="$3"
DEBUG="$4"
DEBUG_SETUP="$5"

if [ "$DEBUG" = "debug" ]; then
	set -e
	set -x
else
	set +e
fi

if [ -z "$TTS_IMAGE" ]; then
	TTS_IMAGE="mj41/tt-server:latest"
fi
if [ -z "$TTCL_IMAGE" ]; then
	TTCL_IMAGE="mj41/tt-client:latest"
fi

if [ "$CMD" != "setup" -a "$CMD" != "start" -a "$CMD" != "stop" -a "$CMD" != "rm" -a "$CMD" != "wbash" ]; then
    echo "Missing/unknown second parameter 'setup', 'start', 'stop', 'rm' or 'wbash'."
    echo
    echo_help
    exit 1
fi

CLIENT=0
SERVER=0
if [ "$CMD" != "wbash" ]; then
	if [ "$CLIENT_PAR" != "client" -a "$CLIENT_PAR" != "no-client" -a "$CLIENT_PAR" != "client-only" ]; then
		echo "Missing/unknown third parameter 'client', 'no-client' or 'client-only'."
		echo
		echo_help
		exit 1
	fi
	if [ "$CLIENT_PAR" != "no-client" ]; then
		CLIENT=1
	fi
	if [ "$CLIENT_PAR" != "client-only" ]; then
		SERVER=1
	fi
	if [ "$DEBUG_SETUP" -a "$DEBUG_SETUP" != "yes_ttdev_magic" ]; then
		echo "Unknown option '$DEBUG_SETUP'."
		echo
		echo_help
		exit 1
	fi
fi

CNAME_DB="${CNAME_PREFIX}-s-db"
CNAME_DB_DATA="${CNAME_PREFIX}-s-db-data"
CNAME_REPOS="${CNAME_PREFIX}-repos"
CNAME_WEB_DATA="${CNAME_PREFIX}-s-data"
CNAME_WEB_CONF="${CNAME_PREFIX}-s-web-conf"
CNAME_WEB="${CNAME_PREFIX}-s-web"
CNAME_WEB_DEBUG="${CNAME_PREFIX}-s-web-debug"
CNAME_WORKER_REPOS="${CNAME_PREFIX}-s-wrepos"
CNAME_WORKER_TESTS="${CNAME_PREFIX}-s-wtests"
CNAME_WORKER_IRC="${CNAME_PREFIX}-s-wirc"
CNAME_CLIENT="${CNAME_PREFIX}-cl"
CNAME_CLIENT_DATA="${CNAME_PREFIX}-c-data"


# Setup: Client and/or server parts.
if [ "$CMD" == "setup" ]; then
	if [ $(container_exists $CNAME_REPOS) = "yes" ]; then
		echo "Container $CNAME_REPOS already exist."
	else
		# Prepare 'repos' data container.
		docker run -i -t --name $CNAME_REPOS -v /opt/taptinder/repos busybox /bin/sh -c \
		  'adduser -u 461 -D ttus ttus ; chown ttus:ttus -R /opt/taptinder/repos ; chmod -R a+rwx /opt/taptinder/repos'
	fi
fi

# Setup: Server.
if [ "$CMD" == "setup" -a "$SERVER" == 1 ]; then

	if [ $(container_exists $CNAME_DB_DATA) = "yes" ]; then
		echo "Container $CNAME_DB_DATA already exist."
	else
		# Prepare 'db-data'
		docker run -i -t --name $CNAME_DB_DATA -v /var/lib/mysql busybox /bin/sh -c 'chmod -R a+rwx /var/lib/mysql'
		# Grant 'with grant options' to root@%.
		docker run --rm -i -t --volumes-from $CNAME_DB_DATA -v ~/scripts/:/root/scripts/:r dockerfile/mariadb /bin/bash -c $" \
		   mysql_install_db && \
		   (/usr/bin/mysqld_safe --datadir='/var/lib/mysql' &>/dev/null &) && sleep 3 && \
		   mysql -uroot -e \$\"grant all privileges on *.* to 'root'@'%' with grant option; FLUSH PRIVILEGES;\" && \
		   mysql -uroot -e 'SELECT User,Host,Password FROM mysql.user'; \
		"
	fi

	if [ $(container_exists $CNAME_DB) = "yes" ]; then
		echo "Container $CNAME_DB already exist."
	else
		# Start 'db'
		docker run -d --name $CNAME_DB --volumes-from $CNAME_DB_DATA dockerfile/mariadb
	fi

	if [ $(container_exists $CNAME_WEB_DATA) = "yes" ]; then
		echo "Container $CNAME_WEB_DATA already exist."
	else
		# Prepare server data container.
		docker run -i -t --name $CNAME_WEB_DATA -v /opt/taptinder/server/data busybox /bin/sh -c \
		  'adduser -u 461 -D ttus ttus ; chown ttus:ttus -R /opt/taptinder/server ; chmod -R u+rwx,go-rwx /opt/taptinder/server'
	fi

	if [ $(container_exists $CNAME_WEB_CONF) = "yes" ]; then
		echo "Container $CNAME_WEB_CONF already exist."
	else
		# Prepare server configuration container.
		docker run -i -t --name $CNAME_WEB_CONF -v /opt/taptinder/server/conf busybox /bin/sh -c \
		  'adduser -u 461 -D ttus ttus ; chown ttus:ttus -R /opt/taptinder/server ; chmod -R u+rwx,go-rwx /opt/taptinder/server'
	fi
fi

# To debug ttdocker-setup.sh procedure.
if [ "$CMD" = "wbash" -o "$DEBUG_SETUP" == 1 ]; then
	LOCAL_TTDEV_DIR="$HOME/ttdev"
	if [ ! -d "$LOCAL_TTDEV_DIR/tt-server" ]; then
		echo "Directory '$LOCAL_TTDEV_DIR/tt-server' not found."
		exit 1
	fi
	chcon -Rt svirt_sandbox_file_t $LOCAL_TTDEV_DIR

	PORT_MAPPING="2000:2000"
	if [ "$CMD" = "wbash" ]; then
		PORT_MAPPING="2001:2000"
		echo "To debug web application (mapped to host port 2001) run:"
		echo "cd /home/ttus/ttdev/tt-server/ ; script/taptinder_web_server.pl -r -p 2000"
		echo ""
	else
		echo "To debug setup procedure you can run:"
		echo "cd /home/ttus/ttdev/tt-server/ ; utils/ttdocker-setup.sh force-setup base"
		echo ""
	fi
	docker run -i -t --rm -p $PORT_MAPPING --link $CNAME_DB:db -u ttus --name $CNAME_WEB_DEBUG \
	  --volumes-from $CNAME_REPOS --volumes-from $CNAME_WEB_DATA --volumes-from $CNAME_WEB_CONF \
	  -v $LOCAL_TTDEV_DIR:/home/ttus/ttdev:rw $TTS_IMAGE /bin/bash
fi

# Run ttdocker-setup.sh and start server.
if [ "$CMD" == "setup" -a "$SERVER" == 1 ]; then
	if [ $(container_exists $CNAME_WEB) = "yes" ]; then
		echo "Container $CNAME_WEB already exist."
	else
		docker run -d -p 2000:2000 --link $CNAME_DB:db -u ttus --name $CNAME_WEB \
		  --volumes-from $CNAME_REPOS --volumes-from $CNAME_WEB_DATA --volumes-from $CNAME_WEB_CONF \
		  $TTS_IMAGE /bin/bash -c \
		  'utils/ttdocker-setup.sh no-force base && script/taptinder_web_server.pl -r -p 2000'
	fi
fi

# Setup: Client.
if [ "$CMD" == "setup" -a "$CLIENT" == 1 ]; then
	if [ $(container_exists $CNAME_CLIENT_DATA) = "yes" ]; then
		echo "Container $CNAME_CLIENT_DATA already exist."
	else
		# Prepare 'client' data container.
		docker run -i -t --name $CNAME_CLIENT_DATA -v /opt/taptinder/client busybox /bin/sh -c \
		  'adduser -u 460 -D ttucl ttucl ; chown ttucl:ttucl -R /opt/taptinder/client ; chmod -R u+rwx,go-rwx /opt/taptinder/client'
	fi

	if [ $(container_exists $CNAME_WEB) = "no" ]; then
		echo "Container $CNAME_WEB not found. Please create it first."
		exit 1
	fi

	if [ $(container_exists $CNAME_CLIENT) = "yes" ]; then
		echo "Container $CNAME_CLIENT already exist."
	else
		docker run -d --link $CNAME_WEB:web -u ttucl --name $CNAME_CLIENT \
		  --volumes-from $CNAME_REPOS --volumes-from $CNAME_CLIENT_DATA \
		  $TTCL_IMAGE
	fi
fi

# Run worker to get new commits to db.
if [ "$CMD" == "setup" -a "$SERVER" == 1 ]; then
	if [ $(container_exists $CNAME_WORKER_REPOS) = "yes" ]; then
		echo "Container $CNAME_WORKER_REPOS already exist."
	else
		# ToDo - remove sql/data-dev-jobs.pl
		docker run -d --link $CNAME_DB:db -u ttus --name $CNAME_WORKER_REPOS \
		  --volumes-from $CNAME_REPOS --volumes-from $CNAME_WEB_CONF \
		  $TTS_IMAGE /bin/bash -c \
		  'sleep 100 ; cd cron ; perl repository-update.pl --project tt-tr1 ; perl repository-update.pl --project tt-tr2 ; \
		   perl repository-update.pl --project tt-tr3 ; cd .. ; perl utils/db-fill-sqldata.pl sql/data-dev-jobs.pl ; \
		   cd cron ; ./loop-dev.sh'
	fi
fi

# Run worker to get test results to db.
if [ "$CMD" == "setup" -a "$SERVER" == 1 ]; then
	if [ $(container_exists $CNAME_WORKER_TESTS) = "yes" ]; then
		echo "Container $CNAME_WORKER_TESTS already exist."
	else
		# ToDo - remove sql/data-dev-jobs.pl
		docker run -d --link $CNAME_DB:db -u ttus --name $CNAME_WORKER_TESTS \
		  --volumes-from $CNAME_WEB_CONF --volumes-from $CNAME_WEB_DATA \
		  $TTS_IMAGE /bin/bash -c \
		  'sleep 100 ; cd cron ; ./loop-tests-to-db.sh'
	fi
fi

# Run worker to report results on IRC.
if [ "$CMD" == "setup" -a "$SERVER" == 1 ]; then
	if [ $(container_exists $CNAME_WORKER_IRC) = "yes" ]; then
		echo "Container $CNAME_WORKER_IRC already exist."
	else
		# ToDo - remove sql/data-dev-jobs.pl
		docker run -d --link $CNAME_DB:db -u ttus --name $CNAME_WORKER_IRC \
		  --volumes-from $CNAME_WEB_CONF \
		  $TTS_IMAGE /bin/bash -c \
		  'sleep 100 ; cd cron ; perl ttbot.pl --ibot_id 1 --db_type local'
	fi
fi

# start
if [ "$CMD" == "start" -a "$SERVER" == 1 ]; then
	docker start $CNAME_DB
	docker start $CNAME_WEB
	docker start $CNAME_WORKER_REPOS
	docker start $CNAME_WORKER_TESTS
	docker start $CNAME_WORKER_IRC
fi
if [ "$CMD" == "start" -a "$CLIENT" == 1 ]; then
	docker start $CNAME_CLIENT
fi

# stop
# Stop order: client, web server, db.
if [ "$CMD" == "stop" -a "$CLIENT" == 1 ]; then
	docker stop $CNAME_CLIENT
fi
if [ "$CMD" == "stop" -a "$SERVER" == 1 ]; then
	docker stop $CNAME_WORKER_IRC
	docker stop $CNAME_WORKER_TESTS
	docker stop $CNAME_WORKER_REPOS
	docker stop $CNAME_WEB
	docker stop $CNAME_DB
fi

# rm
if [ "$CMD" == "rm" -a "$CLIENT" == 1 ]; then
	docker rm -f $CNAME_CLIENT || :
	docker rm -f $CNAME_CLIENT_DATA || :
fi
if [ "$CMD" == "rm" -a "$SERVER" == 1 ]; then
	if [ "$CLIENT" != 1 ]; then
		docker stop $CNAME_CLIENT
	fi
	docker rm -f $CNAME_WORKER_IRC || :
	docker rm -f $CNAME_WORKER_TESTS || :
	docker rm -f $CNAME_WORKER_REPOS || :
	docker rm -f $CNAME_WEB || :
	docker rm -f $CNAME_WEB_DATA || :
	docker rm -f $CNAME_WEB_CONF || :
	docker rm -f $CNAME_REPOS || :
	docker rm -f $CNAME_DB || :
	docker rm -f $CNAME_DB_DATA || :
	exit
fi
