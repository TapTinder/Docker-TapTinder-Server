FROM fedora:21
MAINTAINER Michal Jurosz <docker@mj41.cz>

RUN yum install -y perl \
     perl-Test-Simple perl-Test-More perl-Test-Harness perl-ExtUtils-MakeMaker perl-ExtUtils-Embed \
     perl-ExtUtils-Install perl-Module-Build perl-ExtUtils-MakeMaker perl-Module-Install \
     perl-DBD-MySQL perl-XML-Twig \
     mariadb graphviz expat expat-devel libxml2 libxml2-devel \
     make gcc gcc-c++ tree tar gzip git openssl-devel unzip \
     curl-devel jansson-devel

RUN mkdir /tmp/uwsgi-tmp \
	&& cd /tmp/uwsgi-tmp \
	&& curl -o uwsgi.zip --get -L -O https://github.com/unbit/uwsgi/archive/795caf954327f68bd3f768889b322e95dc5c1e4d.zip \
	&& unzip uwsgi.zip \
	&& mv uwsgi-795caf954327f68bd3f768889b322e95dc5c1e4d uwsgi-src \
	&& curl -o uwsgi-docker.zip --get -L -O https://github.com/unbit/uwsgi-docker/archive/64a103b3ecbfae5970b8182e3409577624a9309d.zip \
	&& unzip uwsgi-docker.zip \
	&& mv uwsgi-docker-64a103b3ecbfae5970b8182e3409577624a9309d uwsgi-docker-src \
	&& cd /tmp/uwsgi-tmp/uwsgi-src \
	&& mkdir /usr/lib/uwsgi \
	&& CPUCOUNT=4 UWSGI_BIN_NAME=/usr/bin/uwsgi python uwsgiconfig.py --build core \
	&& python uwsgiconfig.py --plugin plugins/corerouter package \
	&& python uwsgiconfig.py --plugin plugins/fastrouter package \
	&& python uwsgiconfig.py --plugin plugins/http package \
	&& python uwsgiconfig.py --plugin plugins/cache package \
	&& python uwsgiconfig.py --plugin plugins/logfile package \
	&& python uwsgiconfig.py --plugin plugins/router_metrics package \
	&& python uwsgiconfig.py --plugin plugins/router_static package \
	&& python uwsgiconfig.py --plugin plugins/syslog package \
	&& python uwsgiconfig.py --plugin plugins/psgi package \
	&& python uwsgiconfig.py --plugin /tmp/uwsgi-tmp/uwsgi-docker-src package uwsgi_docker \
	&& cd ~/ \
	&& rm -rf /tmp/uwsgi-tmp/ \
	&& UWSGI_PLUGIN_DIR=/usr/lib/uwsgi uwsgi --plugins fastrouter,cache,logfile,http,router_metrics,router_static,syslog,psgi --version

RUN useradd --uid 461 -U ttus
WORKDIR /home/ttus/
USER ttus
ENV HOME /home/ttus

# ToDo? RUN eval $(perl -I/home/ttus/perl5/lib/perl5/ -Mlocal::lib)
ENV PERL_LOCAL_LIB_ROOT /home/ttus/perl5
ENV PERL_MB_OPT --install_base /home/ttus/perl5
ENV PERL_MM_OPT INSTALL_BASE=/home/ttus/perl5
ENV PERL5LIB /home/ttus/perl5/lib/perl5
ENV PATH /home/ttus/perl5/bin:$PATH

RUN mkdir /tmp/cpanm-ins \
  && cd /tmp/cpanm-ins \
  && curl -LO https://raw.githubusercontent.com/miyagawa/cpanminus/master/cpanm \
  && chmod +x cpanm \
  && export PERL_CPANM_HOME=/tmp/cpanm-ins/ \
  && ./cpanm App::cpanminus \
  && cd /home/ttus \
  && rm -rf /tmp/cpanm-ins

# ToDo remove --force
# ToDo CPAN needed by Catalyst::Devel
RUN mkdir -p -m 0777 /tmp/cpanm/ \
  && export PERL_CPANM_HOME=/tmp/cpanm/ \
  && ~/perl5/bin/cpanm --force -v Tree::XPathEngine Catalyst::Model::DBIC::Schema \
  && ~/perl5/bin/cpanm -v autodie YAML YAML::Syck DateTime Term::ReadKey JSON File::Copy::Recursive Archive::Tar \
     Git::Repository File::ReadBackwards TAP::Harness::Archive LWP::UserAgent Term::Size::Any XML::Feed \
     IO::CaptureOutput IO::String  XML::Simple HTML::TreeBuilder HTML::Entities::Numbered \
     JSON::XS Scalar::Util Encode \
     DBIx::Class Bot::BasicBot::Pluggable \
     Catalyst::Runtime Catalyst::Plugin::Session::State::Cookie Catalyst::Plugin::Session::Store::FastMmap \
     Catalyst::Plugin::Static::Simple Catalyst::Plugin::Config::Multi Catalyst::View::TT Catalyst::View::JSON \
     Catalyst::Plugin::StackTrace Catalyst::Action::RenderView Catalyst::Plugin::SmartURI \
     Catalyst::Authentication::Store::DBIx::Class Catalyst::Model::File \
  && ~/perl5/bin/cpanm --force -v MooseX::Daemonize Catalyst::Controller::REST Catalyst::Plugin::Authorization::Roles \
  && ~/perl5/bin/cpanm -v CPAN \
  && ~/perl5/bin/cpanm -v Starman SQL::Translator GraphViz Catalyst::Restarter FCGI FCGI::ProcManager \
  && rm -rf /tmp/cpanm/ \
  && echo "cpanm finished ok"

RUN git clone https://github.com/TapTinder/TapTinder.git tt-server
WORKDIR /home/ttus/tt-server
RUN mkdir -p third-party
WORKDIR /home/ttus/tt-server/third-party/
RUN git clone https://github.com/mj41/Git-Repository-LogRaw.git

WORKDIR /home/ttus/tt-server
RUN echo "Force Docker image rebuild of TapTinder server to particular revision." \
  && git fetch && git reset --hard 5f211e0 \
  && git log -n1 --oneline HEAD

ADD taptinder_web.uwsgi.ini /home/ttus/ttdev/docker-server/

USER root
RUN rm -rf /tmp/* /var/tmp/* || :
USER ttus

ENV TAPTINDER_COMPONENT server
ENV TAPTINDER_REPOS_DIR /opt/taptinder/repos
ENV TAPTINDER_SERVER_CONF_DIR /opt/taptinder/server/conf
ENV TAPTINDER_SERVER_DATA_DIR /opt/taptinder/server/data
EXPOSE 2000
CMD /bin/bash
