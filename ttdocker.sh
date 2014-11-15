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
CNAME_CLIENT="${CNAME_PREFIX}-cl"
CNAME_CLIENT_DATA="${CNAME_PREFIX}-c-data"


# Setup: Client and/or server parts.
if [ "$CMD" == "setup" ]; then
	# Prepare 'repos' data container.
	docker run -i -t --name $CNAME_REPOS -v /opt/taptinder/repos busybox /bin/sh -c \
	  'adduser -u 461 -D ttus ttus ; chown ttus:ttus -R /opt/taptinder/repos ; chmod -R a+rwx /opt/taptinder/repos'
fi

# Setup: Server.
if [ "$CMD" == "setup" -a "$SERVER" ]; then
	# Prepare 'db-data'
	docker run -i -t --name $CNAME_DB_DATA -v /var/lib/mysql busybox /bin/sh -c 'chmod -R a+rwx /var/lib/mysql'
	# Grant 'with grant options' to root@%.
	docker run --rm -i -t --volumes-from $CNAME_DB_DATA -v ~/scripts/:/root/scripts/:r dockerfile/mariadb /bin/bash -c $" \
	   mysql_install_db && \
	   (/usr/bin/mysqld_safe --datadir='/var/lib/mysql' &>/dev/null &) && sleep 3 && \
	   mysql -uroot -e \$\"grant all privileges on *.* to 'root'@'%' with grant option; FLUSH PRIVILEGES;\" && \
	   mysql -uroot -e 'SELECT User,Host,Password FROM mysql.user'; \
	"
	# Start 'db'
	docker run -d --name $CNAME_DB -p 3306:3306 --volumes-from $CNAME_DB_DATA dockerfile/mariadb

	# Prepare server data container.
	docker run -i -t --name $CNAME_WEB_DATA -v /opt/taptinder/server/data busybox /bin/sh -c \
	  'adduser -u 461 -D ttus ttus ; chown ttus:ttus -R /opt/taptinder/server ; chmod -R u+rwx,go-rwx /opt/taptinder/server'

	# Prepare server configuration container.
	docker run -i -t --name $CNAME_WEB_CONF -v /opt/taptinder/server/conf busybox /bin/sh -c \
	  'adduser -u 461 -D ttus ttus ; chown ttus:ttus -R /opt/taptinder/server ; chmod -R u+rwx,go-rwx /opt/taptinder/server'
fi

# To debug ttdocker-setup.sh procedure.
if [ "$CMD" = "wbash" -o "$DEBUG_SETUP" ]; then
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
		echo "cd /home/ttus/ttdev/tt-server/ ; TAPTINDER_SERVER_CONF_DIR=/opt/taptinder/server/conf script/taptinder_web_server.pl -r -p 2000"
		echo ""
	else
		echo "To debug setup procedure you can run:"
		echo "cd /home/ttus/ttdev/tt-server/ ; utils/ttdocker-setup.sh force-setup base"
		echo ""
	fi
	docker run -i -t --rm -p $PORT_MAPPING --link $CNAME_DB:db -u ttus --name $CNAME_WEB_DEBUG \
	  --volumes-from $CNAME_REPOS --volumes-from $CNAME_WEB_DATA --volumes-from $CNAME_WEB_CONF \
	  -v $LOCAL_TTDEV_DIR:/home/ttus/ttdev:rw $TTS_IMAGE /bin/bash

# Run ttdocker-setup.sh and start server.
elif [ "$CMD" == "setup" -a "$SERVER"  ]; then
	docker run -d -p 2000:2000 --link $CNAME_DB:db -u ttus --name $CNAME_WEB \
	  --volumes-from $CNAME_REPOS --volumes-from $CNAME_WEB_DATA --volumes-from $CNAME_WEB_CONF \
	  $TTS_IMAGE /bin/bash -c \
	  'utils/ttdocker-setup.sh && TAPTINDER_SERVER_CONF_DIR=/opt/taptinder/server/conf script/taptinder_web_server.pl -r -p 2000'
fi

# Setup: Client.
if [ "$CMD" == "setup" -a "$CLIENT" ]; then
	# Prepare 'client' data container.
	docker run -i -t --name $CNAME_CLIENT_DATA -v /opt/taptinder/client busybox /bin/sh -c \
	  'adduser -u 460 -D ttucl ttucl ; chown ttucl:ttucl -R /opt/taptinder/client ; chmod -R u+rwx,go-rwx /opt/taptinder/client'

	docker run -d --link $CNAME_WEB:web -u ttucl --name $CNAME_CLIENT \
	  --volumes-from $CNAME_REPOS --volumes-from $CNAME_CLIENT_DATA \
	  $TTCL_IMAGE
fi

# start
if [ "$CMD" == "start" -a "$SERVER" ]; then
	docker start $CNAME_DB
	docker start $CNAME_WEB
fi
if [ "$CMD" == "start" -a "$CLIENT" ]; then
	docker start $CNAME_CLIENT
fi

# stop
# Stop order: client, web server, db.
if [ "$CMD" == "stop" -a "$CLIENT" ]; then
	docker stop $CNAME_CLIENT
fi
if [ "$CMD" == "stop" -a "$SERVER" ]; then
	docker stop $CNAME_WEB
	docker stop $CNAME_DB
fi

# rm
if [ "$CMD" == "rm" ]; then
	docker rm -f $CNAME_CLIENT || :
	docker rm -f $CNAME_CLIENT_DATA || :
	docker rm -f $CNAME_WEB || :
	docker rm -f $CNAME_WEB_DATA || :
	docker rm -f $CNAME_WEB_CONF || :
	docker rm -f $CNAME_REPOS || :
	docker rm -f $CNAME_DB || :
	docker rm -f $CNAME_DB_DATA || :
	exit
fi
