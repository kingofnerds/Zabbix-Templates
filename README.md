# Zabbix-Templates
Zabbix Templates which I have either created or modified.

I have created two MySQL templates which are useful in the case that you don't want to install the zabbix agent on the database server. 

To use them, you will need to put the two perl files in the /usr/lib/zabbix/externalscripts directory and make them executable by the zabbix user. 

The first script mysql_status_check.pl is used by the individual service checks to populate the data. The scond script snmp_mysql_status_discovery.pl is used in the discovery to pull all IP's from the host via snmp so if you have multiple mysql instances on the same server, all will be monitored.

You will need to add the following regular expressions for discovery to work as expected:


"Ignore Loopback IP"	
1	»	"^127\.0\.0\.1$"	[Result is FALSE]
2	»	"^169\.254.*$"	[Result is FALSE]

"Not Null"	
1	»	"^$|\s+"	[Result is FALSE]


You will also want to populate the database username and password in the template macros after import. It is wise to use a user other than root, which has the adequate permissions required to read the mysql statistics. 

You may also change the external script in use to the versions with the mixed case names which have MySQL instead of mysql to hard code the username and password in the script instead of using the template macros.

This template uses the mysql client on the zabbix server to connect to the remote database servers to pull the stats, so it doesn't require the zabbix agent on the remote database servers.
