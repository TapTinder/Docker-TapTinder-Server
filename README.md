Docker Automated build of TapTinder Server
==========================================

Docker files and scripts for TapTinder server installations.

See [taptinder.org](http://www.taptinder.org) for more info.

Join irc://irc.freenode.org/taptinder with your IRC client or use [Web interface](https://webchat.freenode.net/?channels=taptinder).

Docker image
============

Available on [registry.hub.docker.com/u/mj41/tt-server](https://registry.hub.docker.com/u/mj41/tt-server/).

Fast start
==========

    # Setup and start 'ttlocal' containers set.
    ./ttdocker.sh ttlocal setup noclient debug

	# Stop all running 'ttlocal' containers.
    ./ttdocker.sh ttlocal stop

	# Start 'ttlocal' containers.
    ./ttdocker.sh ttlocal stop

    # Explore TapTinder server web interface.
    firefox localhost:2200

Docker intro
============

See [Using Docker](https://docs.docker.com/userguide/usingdocker/)

    # to see your Docker containers
    docker ps -a

    # to see console (new output, similar to --follow mode)
    docker attach ttlocal-s-web
