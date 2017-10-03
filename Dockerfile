# Creates pseudo distributed hadoop 2.7.1
#
# docker build -t gvacaliuc/hadoop-docker .

FROM centos:7

USER root

# install dev tools
RUN yum clean all; \
    rpm --rebuilddb; \
    yum install -y curl which tar sudo openssh-server openssh-clients rsync
# update libselinux. see https://github.com/sequenceiq/hadoop-docker/issues/14
RUN yum update -y libselinux

# more installation things
RUN yum install -y net-tools wget git

# passwordless ssh
RUN ssh-keygen -q -N "" -t dsa -f /etc/ssh/ssh_host_dsa_key
RUN ssh-keygen -q -N "" -t rsa -f /etc/ssh/ssh_host_rsa_key
RUN ssh-keygen -q -N "" -t rsa -f /root/.ssh/id_rsa
RUN cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys



# java
RUN curl -LO 'http://download.oracle.com/otn-pub/java/jdk/8u144-b01/090f390dda5b47b9b721c7dfaa008135/jdk-8u144-linux-x64.rpm' -H 'Cookie: oraclelicense=accept-securebackup-cookie'
RUN rpm -i jdk-8u144-linux-x64.rpm
RUN rm jdk-8u144-linux-x64.rpm

ENV JAVA_HOME /usr/java/default
ENV PATH $PATH:$JAVA_HOME/bin
RUN rm /usr/bin/java && ln -s $JAVA_HOME/bin/java /usr/bin/java


# hadoop
ENV HADOOP_VERSION 2.7.4
RUN curl -s http://apache.mirrors.pair.com/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz | tar -xz -C /usr/local/

#   curl sets the owner to the pid of the command, this fixes
RUN chown root:root -R /usr/local/hadoop-$HADOOP_VERSION
RUN cd /usr/local && ln -s ./hadoop-$HADOOP_VERSION hadoop

#   sets up some nice env vars
ENV HADOOP_PREFIX /usr/local/hadoop
ENV HADOOP_COMMON_HOME /usr/local/hadoop
ENV HADOOP_HDFS_HOME /usr/local/hadoop
ENV HADOOP_MAPRED_HOME /usr/local/hadoop
ENV HADOOP_YARN_HOME /usr/local/hadoop
ENV HADOOP_CONF_DIR /usr/local/hadoop/etc/hadoop

#   sets our java home / hadoop prefix in the environment script
RUN sed -i '/^export JAVA_HOME/ s:.*:export JAVA_HOME=/usr/java/default\nexport HADOOP_PREFIX=/usr/local/hadoop\nexport HADOOP_HOME=/usr/local/hadoop\n:' $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh
RUN sed -i '/^export HADOOP_CONF_DIR/ s:.*:export HADOOP_CONF_DIR=/usr/local/hadoop/etc/hadoop/:' $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh
RUN . $HADOOP_CONF_DIR/hadoop-env.sh

# pseudo distributed = connects to "remote" server @ localhost
ADD core-site.xml.template $HADOOP_PREFIX/etc/hadoop/core-site.xml.template
RUN sed s/HOSTNAME/localhost/ /usr/local/hadoop/etc/hadoop/core-site.xml.template > /usr/local/hadoop/etc/hadoop/core-site.xml

ADD hdfs-site.xml $HADOOP_PREFIX/etc/hadoop/hdfs-site.xml
ADD slaves.template $HADOOP_CONF_DIR/slaves.template

#   Formats the namenode
RUN $HADOOP_PREFIX/bin/hdfs namenode -format

#   Add ssh config, setting permissions as well
ADD ssh_config /root/.ssh/config
RUN chmod 600 /root/.ssh/config
RUN chown root:root /root/.ssh/config

#   Remove references to edcsa / ed25519 keys -- we're only going to ssh from localhost
RUN sed -i.backup -e '/^HostKey.*\(ecdsa\|ed25519\)/s/^/#/' /etc/ssh/sshd_config

#   Adds the bootstrap file and exclusively allow root to RWX
ADD bootstrap.sh /etc/bootstrap.sh
RUN chown root:root /etc/bootstrap.sh
RUN chmod 700 /etc/bootstrap.sh

#   So hadoop bin is already in path
RUN echo "PATH=$PATH:$HADOOP_COMMON_HOME/bin" >> /etc/bashrc

#   For some reason, $USER isn't set correctly by default
RUN echo "USER=root" >> /root/.bashrc

CMD ["/etc/bootstrap.sh", "-d"]

# Hdfs ports
EXPOSE 50010 50020 50070 50075 50090 8020 9000
# Mapred ports
EXPOSE 10020 19888
#Other ports (unknown) (ssh)
EXPOSE 49707 2122
