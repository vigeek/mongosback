## mongosback
**mongosback** is a mongodb backup script created to be easy to use yet flexible, currently a commit or two away for readiness.

#### Installation
Clone or download as zip from github, extract to directory.  Set the main script as executable (chmod u+x mongosback.sh).  Edit mongosback.conf with desired settings and execute from cron.

###### Functionality
* Archiving
  *	keep several backups on-hand, delete after X days.  
* Performance throttling  
  *	mongodb can be quite resource intensive (IO in particular).  
  * three performance throttles (low, normal, high).  
  * reduces IO and CPU utilization, useful for backups on master mongo server.  
* Compression  
  *	perform gzip compression on backups, reducing space utilization.
  * tunable compression levels (low, medium, high).
* Exporting
  * automatically transfer latest backup to remote FTP or using SCP.
* Logging
  * logging of all events to log file and optionally syslog.
  * debug mode, copies all mongodump output to debug file to determine failures.
  * calculates total run time and dump size to understand data growth impact.
* e-mail notifications
  *	get updated on successful or failed backup attempts.
  * includes run time and dump size, on-hand archives and target disk utilization.
* write locking
  * option to enable write locking on replicaSet slaves.
  * locks writes, performs backup, unlock writes (slave nodes only).
  * helps ensure a consistent state (also consider: --oplog option)
* configurability
  * changeable backup path
  * ability to set mongodump runtime options.
  * many others in configuration file.


###### license

GPL v3

###### contact

Russ Thompson (russ a@t linux.com).  actively maintained, please submit issues or suggestions.