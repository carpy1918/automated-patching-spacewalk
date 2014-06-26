#!/bin/bash

spacecmd -s fclpspcwksch01 -u apiuser -y -p 'Api#Pas0420' group_delete PB-IGNORE
spacecmd -s fclpspcwksch01 -u apiuser -y -p 'Api#Pas0420' group_create PB-IGNORE "patching: ignore svrs" 
