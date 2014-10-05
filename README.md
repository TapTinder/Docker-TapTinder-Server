Docker Automated build of TapTinder Server
==========================================

Docker files and scripts for TapTinder server installations.

See [taptinder.org](http://www.taptinder.org) for more info.

Join irc://irc.freenode.org/taptinder with your IRC client or use [Web interface](https://webchat.freenode.net/?channels=taptinder)).

Docker image
============

Available on [registry.hub.docker.com/u/mj41/tt-server](https://registry.hub.docker.com/u/mj41/tt-server/).

Fast start
==========

    # download, create and run 'mytts' container
    docker run -i -t -p 2200:2200 -u root --name mytts mj41/tt-server:latest

    # to use TapTinder server web interface
    firefox localhost:2200

Docker intro
============

See [Using Docker](https://docs.docker.com/userguide/usingdocker/)

    # to see your Docker containers
    docker ps -a

    # stop, start already created 'mytts' container
    docker stop mytts
    docker start mytts

    # to see console (new output, similar to --follow mode)
    docker attach mytts

Explore
=======

    # to create 'mytts-exp' and run Bash there
    docker run -i -t -p 2200:2200 -u root --name mytts-exp mj41/tt-server:prod /bin/bash

    # start TapTinder server
    utils/start-server.sh prod d debug

    # run already created 'mytts-exp' container
    docker start -i mytts-exp
