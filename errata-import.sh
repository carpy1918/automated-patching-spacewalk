#!/bin/bash


rm -f errata.latest-*

wget http://cefs.steve-meier.de/errata.latest.xml

/usr/bin/perl /usr/bin/xml_split -s 1Mb errata.latest.xml

rm -f errata.latest-00.xml

export SPACEWALK_USER='apiuser';export SPACEWALK_PASS='Api#Pas0420'

for i in $(ls errata.latest-*);do

sed -i "s/<\/xml_split:root>/<\/opt>/" $i
sed -i "s/<?xml version='1.0' standalone='yes'?>/<?xml version='1.0' standalone='yes'?><opt>/" $i

/usr/bin/perl errata-import.pl --server fclpspcwksch01 --errata $i
done



