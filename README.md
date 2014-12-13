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
    ./ttdocker ttlocal setup client debug

	# Stop all running 'ttlocal' containers.
    ./ttdocker ttlocal stop

	# Start 'ttlocal' containers.
    ./ttdocker ttlocal start

    # Explore TapTinder server web interface.
    firefox localhost:2000

Docker intro
============

See [Using Docker](https://docs.docker.com/userguide/usingdocker/)

    # To see your Docker containers.
    docker ps -a

    # To see console.
    docker attach ttlocal-s-web
