FROM mj41/local-tt-server:my
MAINTAINER Michal Jurosz <docker@mj41.cz>

WORKDIR /home/ttus/tt-server

COPY dev_image_update /home/ttus/
COPY docker_param/* /home/ttus/docker_param/
RUN /home/ttus/dev_image_update
