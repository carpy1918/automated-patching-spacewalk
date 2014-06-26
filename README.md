automated-patching-spacewalk
============================

Bash and Perl scripts for connecting Spacewalk patching efforts to cron, configuration files, or database tables


A set of scripts to do the following:

  -Spacewalk server group management
  -Email notification pre and post patching efforts to business owners
  -Centralized patching efforts connected to cron for scheduling
  -Report generation on patching efforts
  -Basic errata update attempt

The current scripts are configured to use a central MySQL database to pull server and group information to sync with the Spacewalk database. Configuration files are also used to list exceptions and server groups for execution of patching events. 

Curtis
Tealeaf IT

