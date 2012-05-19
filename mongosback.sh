#!/bin/bash
##    \    /.| _||_ ._|_
##     \/\/ ||(_||_)| | 
################################################   
# mongosback - Russ Thompson (russ @ linux.com)               

if [ -f "mongosback.conf" ] ; then
	. ./mongosback.conf
   COMPRESSED_NAME="$(DO_BACKUP)_$(date +%m_%d_%Y)_dump.tar.gz"
else
	logger "mongosback unable to read the configuration file, exiting prematurely"
	exit 1
fi

function log {
	echo -e "$(date) $1" >> $LOG_FILE
    if [ $SYSLOG -eq 1 ] ; then
      logger "mongosback - $1"
    fi
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
		PERFORMANCE_THROTTLING="ionice -c2 -n6 nice -n 5"
	elif [ $PERFORMANCE_THROTTLING == "normal" ] ; then
		PERFORMANCE_THROTTLING="nice -n 0"
	elif [ $PERFORMANCE_THROTTLING == "high" ] ; then
		PERFORMANCE_THROTTLING="ionice -c2 -n6 nice -n -5"
	else
		PERFORMANCE_THROTTLING="nice -n 0"
	fi

	if [ $COMPRESS -eq "0" ] ; then
		COMPRESSED_NAME=`$(echo $COMPRESSED_NAME | sed 's/.gz//g')`
	fi

  if [ -z "$MONGO_DUMP" ] ; then
    MONGO_DUMP=`which mongodump`
  fi
}

function archive {

  if [ $COMPRESS -eq "1" ] ; then
    if [ -d "$BACKUP_PATH/$DO_BACKUP" ] ; then
      log "compressing backup" >> $LOG_FILE
      GZIP=$COMPRESSION_LEVEL ; tar -czvf $COMPRESSED_NAME $BACKUP_PATH/$DO_BACKUP
    else
      log "ERROR-> $DO_BACKUP does not exst."
      exit 1
    fi
  fi


  if [ $DAYS_TO_KEEP -gt "1" ] ; then
    TO_DELETE=`find $COMPRESS_STORE -name "dump.tar" -type f -mtime +$DAYS_TO_KEEP`
      if [ ! -z "$TO_DELETE" ] ; then
        log "deleting files older than $DAYS_TO_KEEP days:"
        find $COMPRESS_STORE -name "dump.tar" -type f -mtime +$DAYS_TO_KEEP -exec du -hs {} \; >> $LOG_FILE
        find $COMPRESS_STORE -name "dump.tar" -type f -mtime +$DAYS_TO_KEEP -exec rm {} \;
      fi
  else
    find $COMPRESS_STORE -name "dump.tar" -exec rm {} \;
  fi
}
  
log "starting mongodump...." 
START_TIME=$(date +%s)

prepare_job()

log "$(date) starting mongodump (this will take a while)...." 

cd $BACKUP_PATH
if [ -d "$BACKUP_PATH/$DO_BACKUP"  ] ; then
  log "cleaning up previous backup directory..." 
  rm -rf $BACKUP_PATH/$DO_BACKUP
fi

$PERFORMANCE_THROTTLING $MONGO_DUMP -h $MONGO_HOST_PORT -d $DO_BACKUP -o $BACKUP_PATH $MONGO_DUMP_OPTIONS

  if [ $? -ne 0 ] ; then
    log "ERROR -> mongo_dump failed to execute properly: err $?"
    log "mongosback terminating early" 
    exit 1
  fi
echo -e "$(date) mongodump successful, beginning post-dump operations" 

archive()

END_TIME=$(date +%s)
TIME_DIFF=$(( $END_TIME - $START_TIME ))
TIME_DIFF=`echo $(($TIME_DIFF / 60 ))`
log "finished mongodump in $TIME_DIFF minutes..." 

echo "------------------------------------------------------------------------------------" >> $LOG_FILE

exit 0