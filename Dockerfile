FROM centos:6

RUN yum -y update
RUN yum -y install which tar

RUN gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
RUN \curl -sSL https://get.rvm.io | /bin/bash -s stable

RUN /bin/bash -l -c "rvm requirements"
RUN /bin/bash -l -c "rvm install 1.9.3-p547"
RUN /bin/bash -l -c "rvm use 1.9.3-p547 --default"

#RUN yum -y install rubygems
RUN /bin/bash -l -c "gem install bundler --no-ri --no-rdoc"

RUN yum -y install libxml2 libxml2-devel libxslt libxslt-devel libcurl libcurl-devel mysql-devel mysql-server git

ENV APP_HOME /virgo
RUN mkdir $APP_HOME
WORKDIR $APP_HOME

ADD . $APP_HOME

RUN /bin/bash -l -c "bundle install"

EXPOSE 3000
CMD /bin/bash -l -c "$APP_HOME/docker-start.sh"
