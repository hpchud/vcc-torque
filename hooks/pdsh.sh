#!/bin/bash

# generate the /etc/vcc/pdsh_machines file
# pdsh just wants machine name on each line of file

echo -n > /etc/vcc/pdsh_machines

INIT_RUN_DIR="${INIT_RUN_DIR:-/run}"

cat $INIT_RUN_DIR/hosts.vcc | while read line; do
	host="`echo $line | awk '{print $2}'`"
	ip="`echo $line | awk '{print $1}'`"
	if [ "$host" != "`hostname`" ]; then
		echo "$ip" >> /etc/vcc/pdsh_machines
	fi
done