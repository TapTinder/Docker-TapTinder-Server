FROM centos:latest
MAINTAINER Michal Jurosz <docker@mj41.cz>

RUN yum install -y perl perl-Test-Simple perl-Test-More perl-Test-Harness perl-ExtUtils-MakeMaker \
     perl-ExtUtils-Install perl-Module-Build perl-ExtUtils-MakeMaker perl-DBD-MySQL \
     mariadb graphviz expat expat-devel \
     make gcc gcc-c++ tree tar gzip git openssl-devel \
  && yum clean all

RUN useradd taptinder
WORKDIR /home/taptinder/
USER taptinder
ENV HOME /home/taptinder

# ToDo? RUN eval $(perl -I/home/taptinder/perl5/lib/perl5/ -Mlocal::lib)
ENV PERL_LOCAL_LIB_ROOT /home/taptinder/perl5
ENV PERL_MB_OPT --install_base /home/taptinder/perl5
ENV PERL_MM_OPT INSTALL_BASE=/home/taptinder/perl5
ENV PERL5LIB /home/taptinder/perl5/lib/perl5
ENV PATH /home/taptinder/perl5/bin:$PATH

RUN mkdir /tmp/cpanm-ins \
  && cd /tmp/cpanm-ins \
  && curl -LO https://raw.githubusercontent.com/miyagawa/cpanminus/master/cpanm \
  && chmod +x cpanm \
  && export PERL_CPANM_HOME=/tmp/cpanm-ins/ \
  && ./cpanm App::cpanminus \
  && cd /home/taptinder \
  && rm -rf /tmp/cpanm-ins

# ToDo remove --force
# ToDo CPAN needed by Catalyst::Devel
RUN mkdir -p -m 0777 /tmp/cpanm/ \
  && export PERL_CPANM_HOME=/tmp/cpanm/ \
  && ~/perl5/bin/cpanm  YAML YAML::Syck DateTime Term::ReadKey JSON File::Copy::Recursive Archive::Tar Git::Repository \
     File::ReadBackwards TAP::Harness::Archive LWP::UserAgent Term::Size::Any \
  && ~/perl5/bin/cpanm  Catalyst::Runtime Catalyst::Plugin::Session::State::Cookie Catalyst::Plugin::Session::Store::FastMmap \
     Catalyst::Plugin::Static::Simple Catalyst::Plugin::Config::Multi Catalyst::View::TT Catalyst::View::JSON \
     Catalyst::Model::DBIC::Schema Catalyst::Plugin::StackTrace Catalyst::Action::RenderView \
     Catalyst::Authentication::Store::DBIx::Class Catalyst::Model::File Catalyst::Controller::REST \
     Catalyst::Plugin::Authorization::Roles \
  && ~/perl5/bin/cpanm --force -v MooseX::Daemonize Module::Install \
  && ~/perl5/bin/cpanm CPAN \
  && ~/perl5/bin/cpanm Starman SQL::Translator GraphViz Catalyst::Restarter FCGI FCGI::ProcManager \
  && rm -rf /tmp/cpanm/

RUN git clone https://github.com/mj41/TapTinder.git tt-server
WORKDIR /home/taptinder/tt-server
RUN echo "Force Docker image rebuild of TapTinder server to particular revision." \
  && git fetch && git reset --hard d0a52f948192 \
  && git log -n1 --oneline HEAD

ENV TAPTINDER_COMPONENT server
EXPOSE 2000
CMD script/taptinder_web_server.pl -r -p 2000
