#!/bin/bash

# The purpose of this script is to set the maui server name on the
# first boot of the head node.

oldname="`cat /usr/local/maui/maui.cfg | grep SERVERHOST | awk '{print $2}'`"
newname="`hostname`"
sed -i "s/$oldname/$newname/g" /usr/local/maui/maui.cfg
