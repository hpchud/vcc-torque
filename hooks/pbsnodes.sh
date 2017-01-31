#!/bin/bash

# generate the /var/spool/torque/server_priv/nodes file

echo -n > /var/spool/torque/server_priv/nodes

cat /etc/hosts.vcc | while read line; do
	host="`echo $line | awk '{print $2}'`"
	if [ "$host" != "`hostname`" ]; then
		# torque can not handle a hostname that starts with a number,
		# so we prepend vccnode and ClusterDNS will alias this for us
		echo "vnode_$host" >> /var/spool/torque/server_priv/nodes
	fi
done

# kill the torque server without stopping jobs
qterm -t quick

# have to kill maui too, but give time for pbs_server to restart
sleep 5
kill `cat /var/run/maui.pid`

# using auto_node_np confuses maui, so save auto detected nps
# wait another few seconds incase auto detection is taking awhile
sleep 3
cat /var/spool/torque/server_priv/nodes | while read line; do
	node="`echo $line | awk '{print $1}'`"
	np="`pbsnodes $node | grep np | awk '{print $3}'`"
	qmgr -c "set node $node np=$np"
done