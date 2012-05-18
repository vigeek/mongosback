#!/bin/bash
##    \    /.| _||_ ._|_
##     \/\/ ||(_||_)| | 
################################################                  
## MongoDB backup script.
## Russ Thompson - 3/29/2012


MONGO_DUMP="/usr/bin/mongodump"
MONGO_HOST_PORT="127.0.0.1:27020"
MONGO_DUMP_OPTIONS="--forceTableScan"
DO_BACKUP="db_name"

LOG_FILE="/var/log/mongo-backup.log"
BACKUP_PATH="/mongo_backup"

# Archive options
#
ARCHIVE="1"
DAYS_TO_KEEP="3"
COMPRESS="1"
COMPRESSED_NAME="$(DO_BACKUP)_dump_$(date +%m_%d_%Y).tar.gz"
# Compression level (accepts: low, medium, high)
COMPRESSION_LEVEL="low"
# End Archiving options.

# Performance throttling (accepts:  low, normal, high)
PERFORMANCE_THROTTLING="normal"

function log {
	echo -e "$(date) $1" >> $LOG_FILE
}

function prepare_job {
	if [ $COMPRESSION_LEVEL == "low" ] ; then
		COMPRESSION_LEVEL="-1"
	elif [ $COMPRESSION_LEVEL == "normal" ] ; then
		COMPRESSION_LEVEL="-5"
	elif [ $COMPRESSION_LEVEL == "high" ] ; then
		COMPRESSION_LEVEL="-9"
	else
		COMPRESSION_LEVEL="-5"
	fi

	if [ $PERFORMANCE_THROTTLING == "low" ] ; then
		PERFORMANCE_THROTTLING="ionice -c2 -n6 nice -n 2"
	elif [ $PERFORMANCE_THROTTLING == "normal" ] ; then
		PERFORMANCE_THROTTLING="nice -n 0"
	elif [ $PERFORMANCE_THROTTLING == "high" ] ; then
		PERFORMANCE_THROTTLING="ionice -c2 -n6 nice -n 2"
	else
		PERFORMANCE_THROTTLING="nice -n 0"
	fi
}

function archive {

	if [ $COMPRESS -eq "1" ] ; then
	  if [ -d "$BACKUP_PATH/$DO_BACKUP" ] ; then
	    echo -e "$(date) compressing backup...." >> $LOG_FILE
	    GZIP=-1 tar -czvf $COMPRESSED_NAME $BACKUP_PATH/$DO_BACKUP
	  else
	    log "ERROR-> $DO_BACKUP does not exst."
	    exit 1
	  fi
	fi


	if [ $DAYS_TO_KEEP -gt "1" ] ; then
	  TO_DELETE=`find $COMPRESS_STORE -name "*.gz" -type f -mtime +$DAYS_TO_KEEP`
	    if [ ! "$TO_DELETE" == "" ] ; then
	      echo -e "$(date) Deleting files older than $DAYS_TO_KEEP days:" >> $LOG_FILE
	      find $COMPRESS_STORE -name "*.gz" -type f -mtime +$DAYS_TO_KEEP -exec du -hs {} \; >> $LOG_FILE
	      find $COMPRESS_STORE -name "*.gz" -type f -mtime +$DAYS_TO_KEEP -exec rm {} \;
	    fi
	else
	  rm -f $COMPRESS_STORE/*.gz
	fi
	
}


log "starting mongodump...." 
START_TIME=$(date +%s)

log "$(date) starting mongodump (this will take a while)...." 

cd $BACKUP_PATH
if [ -d "$BACKUP_PATH/$DO_BACKUP"  ] ; then
  log "cleaning up previous backup directory..." 
  rm -rf $BACKUP_PATH/$DO_BACKUP
fi

$PERFORMANCE_THROTTLING $MONGO_DUMP -h $MONGO_HOST_PORT -d $DO_BACKUP -o $BACKUP_PATH $MONGO_DUMP_OPTIONS
  if [ $? -ne 0 ] ; then
    log "ERROR -> mongo_dump failed to execute properly: err $?"
    log "mongo backup terminating early" 
    exit 1
  fi
echo -e "$(date) mongodump successful, beginning post-dump operations" 



END_TIME=$(date +%s)
TIME_DIFF=$(( $END_TIME - $START_TIME ))
echo -e "$(date) finished mongodump in $TIME_DIFF seconds..." 

echo "------------------------------------------------------------------------------------" >> $LOG_FILE

exit 0
