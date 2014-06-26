#!/bin/bash

/etc/init.d/postgresql restart
sleep 1
/etc/init.d/tomcat6 restart
sleep 1
/etc/init.d/httpd restart
sleep 1
/etc/init.d/jabberd restart
sleep 1
/etc/init.d/osa-dispatcher restart

