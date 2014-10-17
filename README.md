## mongosback 0.91
**mongosback** is a mongodb backup script created to be easy to use yet flexible, used in production at Wildbit.com

#### Installation
Clone or download as zip from github, extract to directory.  Set the main script as executable (chmod u+x mongosback.sh).  Edit mongosback.conf with desired settings and execute from cron.

Upon running, you may provide the path to mongosback.conf by executing with "-f".  Example:

./mongosback.sh -f /etc/mongosback.conf

###### Compatability
Tested:  Debian, CentOS, RHEL

###### Functionality
* Archiving
  *	keep several backups on-hand, delete after X days.  
* Performance throttling  
  *	mongodb can be quite resource intensive (IO in particular).  
  * three performance throttles (low, normal, high).  
  * reduces IO and CPU utilization, useful for backups on master mongo server.  
* Compression  
  *	perform gzip compression on backups, reducing space utilization.
  * tunable compression levels (fast, normal, best).
* Simple backup
  *     optional simple backup method to bypass compression, archiving and exporting.
  * useful if simple dumps are needed with performance throttling and erorr handling.
* Exporting
  * automatically transfer latest backup to remote FTP or using SCP.
* Logging
  * logging of all events to log file and optionally syslog.
  * debug mode, copies all mongodump output to debug file to determine failures.
  * calculates total run time and dump size to understand data growth impact.
* E-mail notifications
  *	get updated on successful or failed backup attempts.
  * includes run time and dump size, on-hand archives and target disk utilization.
* Write locking
  * option to enable write locking on replicaSet slaves.
  * locks writes, performs backup, unlock writes (slave nodes only).
  * helps ensure a consistent state (also consider: --oplog option)
* Configurability
    * changeable backup path
    * ability to set mongodump runtime options.
    * many others in configuration file.
* General
    * creates pid file to prevent multiple startups.
    * traps errors caught, logs and optionally e-mails.
    * can be run as non root user

###### Note on mongoDB rights if using auth
User roles need to contain **userAdmin** because mongodump backup db.system.users.
For now, there is no option to tell mongodump not backuping this users collection.
Update:  For MongoDB 2.6, user needs to have the backup and hostManager (for clusters) roles 

###### license

GPL v3

###### contact

Russ Thompson (russ a@t linux.com).  actively maintained, please submit issues or suggestions.

