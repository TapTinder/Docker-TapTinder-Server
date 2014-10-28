#/bin/bash

set -e
set -x

function echo_help {
cat <<USAGE_END
Usage:
  ttdocker.sh ttlocal|ttdev|ttprod|tt... start|stop|rm client|noclient [debug]

  Orchestrate your TapTinder containers for

  ttlocal ... local purpose
  ttdev ... TapTinder development purpose
  ttprod ... production purpose

  setup ... setup all containers
  start ... start all containers
  stop ... stop all containers
  rm ... remove all containers (delete all data)

  client ... start also testing (tt-client container)
  noclient ... do not start tt-client container

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
CLIENT="$3"
DEBUG="$4"
DEBUG_SETUP="$6"

if [ -z "$TTS_IMAGE" ]; then
	TTS_IMAGE="mj41/tt-server:latest"
fi
if [ -z "$TTCL_IMAGE" ]; then
	TTCL_IMAGE="mj41/tt-client:latest"
fi

if [ "$CMD" != "setup" -a "$CMD" != "start" -a "$CMD" != "stop" -a "$CMD" != "rm" ]; then
    echo "Missing/unknown second parameter 'start', 'stop' or 'rm'."
    echo
    echo_help
    exit 1
fi

if [ "$DEBUG_SETUP" -a "$DEBUG_SETUP" != "yes_ttdev_magic" ]; then
	echo "Unknown option '$DEBUG_SETUP'."
	echo
	echo_help
	exit 1
fi

CNAME_DB="${CNAME_PREFIX}-s-db"
CNAME_DB_DATA="${CNAME_PREFIX}-s-db-data"
CNAME_REPOS="${CNAME_PREFIX}-repos"
CNAME_DATA="${CNAME_PREFIX}-s-data"
CNAME_SETUP="${CNAME_PREFIX}-s-setup"
CNAME_WEB="${CNAME_PREFIX}-s-web"

# Setup data and app containers.
if [ "$CMD" == "setup" ]; then
	# Prepare 'db-data'
	docker run -d -t --name $CNAME_DB_DATA -v /var/lib/mysql busybox /bin/sh
	# Grant 'with grant options' to root@%.
	docker run --rm -i -t --volumes-from $CNAME_DB_DATA -v ~/scripts/:/root/scripts/:r dockerfile/mariadb /bin/bash -c $" \
	   mysql_install_db && \
	   (/usr/bin/mysqld_safe --datadir='/var/lib/mysql' &>/dev/null &) && sleep 3 && \
	   mysql -uroot -e \$\"grant all privileges on *.* to 'root'@'%' with grant option; FLUSH PRIVILEGES;\" && \
	   mysql -uroot -e 'SELECT User,Host,Password FROM mysql.user'; \
	"
	# Start 'db'
	docker run -d --name $CNAME_DB -p 3306:3306 --volumes-from $CNAME_DB_DATA dockerfile/mariadb

	# Prepare 'repos' data container.
	docker run -i -t --name $CNAME_REPOS -v /opt/taptinder/repos busybox /bin/sh -c \
	  'adduser -D -H taptinder ; chown taptinder:taptinder -R /opt/taptinder ; chmod -R a+rwx /opt/taptinder'

	# Prepare 'server' data container.
	docker run -i -t --name $CNAME_DATA -v /opt/taptinder/server busybox /bin/sh -c \
	  'adduser -D -H taptinder ; chown taptinder:taptinder -R /opt/taptinder ; chmod -R a+rwx /opt/taptinder'

	# To debug ttdocker-setup.sh procedure.
	if [ "$DEBUG_SETUP" ]; then
		LOCAL_TTDEV_DIR="$HOME/ttdev"
		if [ ! -d "$LOCAL_TTDEV_DIR/tt-server" ]; then
			echo "Directory '$LOCAL_TTDEV_DIR/tt-server' not found."
			exit 1
		fi
		chcon -Rt svirt_sandbox_file_t $LOCAL_TTDEV_DIR
		echo "You can run:"
		echo "cd /home/taptinder/ttdev/tt-server/ ; utils/ttdocker-setup.sh"
		docker run --rm -i -t -p 2200:2200 --link $CNAME_DB:db -u taptinder --name $CNAME_SETUP \
		  --volumes-from $CNAME_REPOS --volumes-from $CNAME_DATA \
		  -v $LOCAL_TTDEV_DIR:/home/taptinder/ttdev:rw $TTS_IMAGE /bin/bash

	# Run ttdocker-setup.sh.
	else
		docker run --rm -i -t -p 2200:2200 --link $CNAME_DB:db -u taptinder --name $CNAME_SETUP \
		  --volumes-from $CNAME_REPOS --volumes-from $CNAME_DATA \
		  $TTS_IMAGE /bin/bash -c 'cd /home/taptinder/tt-server/ && utils/ttdocker-setup.sh'
	fi

	docker run -d -p 2200:2200 --link $CNAME_DB:db -u taptinder --name $CNAME_WEB $TTS_IMAGE /bin/sh -c \
	  'script/taptinder_web_server.pl -r -p 2200'

fi

if [ "$CMD" == "start" ]; then
	docker start $CNAME_DB
	docker start $CNAME_WEB
fi

if [ "$CMD" == "stop" ]; then
	docker stop $CNAME_WEB
	docker stop $CNAME_DB
	exit
fi

if [ "$CMD" == "rm" ]; then
	docker rm -f $CNAME_DB || :
	docker rm -f $CNAME_DB_DATA || :
	docker rm -f $CNAME_REPOS || :
	docker rm -f $CNAME_DATA || :
	docker rm -f $CNAME_WEB || :
	exit
fi
