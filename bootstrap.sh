#!/bin/bash

#   if the hadoop prefix isn't set, set it
: ${HADOOP_PREFIX:=/usr/local/hadoop}

. $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh

if [[ $(find /tmp -maxdepth 1 -type f -path *.pid | wc -l) -gt 0 ]]; then
    rm /tmp/*.pid
fi

# installing libraries if any - (resource urls added comma separated to the ACP system variable)
cd $HADOOP_PREFIX/share/hadoop/common ; for cp in ${ACP//,/ }; do  echo == $cp; curl -LO $cp ; done; cd -

#   since you can't fix the hostname of a container in docker,
#   we end up having to set it when we launch the container...
sed s/HOSTNAME/$HOSTNAME/ \
    $HADOOP_COMMON_HOME/etc/hadoop/core-site.xml.template > \
    $HADOOP_COMMON_HOME/etc/hadoop/core-site.xml
sed s/HOSTNAME/$HOSTNAME/ \
    $HADOOP_COMMON_HOME/etc/hadoop/slaves.template > \
    $HADOOP_COMMON_HOME/etc/hadoop/slaves

#   crudely start our ssh daemon
SSH_PORT=2122
/usr/sbin/sshd -p $SSH_PORT -D &

$HADOOP_PREFIX/sbin/start-dfs.sh

#   crude approximation for daemon
if [[ $1 == "-d" ]]; then
  while true; do sleep 1000; done
fi

#   give them some bash!
if [[ $1 == "-bash" ]]; then
  /bin/bash
fi
