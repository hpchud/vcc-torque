#!/bin/bash

# generate the /etc/vcc/pdsh_machines file
# pdsh just wants machine name on each line of file

echo -n > /etc/vcc/pdsh_machines

VCC_RUN_DIR="${VCC_RUN_DIR:-/run}"

cat $VCC_RUN_DIR/hosts.vcc | while read line; do
	host="`echo $line | awk '{print $2}'`"
	ip="`echo $line | awk '{print $1}'`"
	if [ "$host" != "`hostname`" ]; then
		echo "$ip" >> /etc/vcc/pdsh_machines
	fi
done