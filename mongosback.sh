#!/bin/bash
##    \    /.| _||_ ._|_
##     \/\/ ||(_||_)| | 
################################################   
# mongosback - Russ Thompson (russ @ linux.com)               

if [ -f "mongosback.conf" ] ; then
	. ./mongosback.conf
   COMPRESSED_NAME="$(DO_BACKUP)_$(date +%m_%d_%Y)_dump.tar"
else
	logger "mongosback unable to read the configuration file, exiting prematurely"
	exit 1
fi

if [ -f "/var/run/mongosback.pid"] ; then
  logger "mongosback - exiting prematurely, pid file exists @ /var/run/mongosback.pid" ; ERR_RETURN="pid existance : $LINENO"
  echo -e "mongosback - exiting prematurely, pid file exists @ /var/run/mongosback.pid" | tee -a $LOG_FILE
  error_trap()
fi

function log {
	echo -e "$(date) $1" >> $LOG_FILE
    if [ $SYSLOG -eq 1 ] ; then
      logger "mongosback - $1"
    fi
}

function error_trap {
  logger "mongosback - error trap called - $ERR_RETURN"
  echo -e "mongosback - error trap called - $ERR_RETURN" | tee -a $LOG_FILE
  if [ -f "$PID_FILE" ] ; then rm -f $PID_FILE ; fi
  exit 1
}

function prepare_job {

	if [ $COMPRESSION_LEVEL == "fast" ] ; then
		COMPRESSION_LEVEL="-1"
	elif [ $COMPRESSION_LEVEL == "normal" ] ; then
		COMPRESSION_LEVEL="-5"
	elif [ $COMPRESSION_LEVEL == "best" ] ; then
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

function compress {
  if [ $COMPRESS -eq "1" ] ; then

    if [ -d "$COMPRESSED_NAME" ] ; then
      log "compressing backup" >> $LOG_FILE
      gzip $COMPRESSION_LEVEL $COMPRESSED_NAME
      COMPRESSED_NAME="$COMPRESSED_NAME.gz"
    else
      log "ERROR-> $DO_BACKUP does not exst." ; ERR_RETURN="compression function : $LINENO"
      error_trap()
    fi
  fi
}

function archive {

  if [ $DAYS_TO_KEEP -gt "1" ] ; then
    TO_DELETE=`find $BACKUP_PATH -name "*dump.tar*" -type f -mtime +$DAYS_TO_KEEP`
      if [ ! -z "$TO_DELETE" ] ; then
        log "deleting files older than $DAYS_TO_KEEP days:"
        find $BACKUP_PATH -name "*dump.tar*" -type f -mtime +$DAYS_TO_KEEP -exec du -hs {} \; >> $LOG_FILE
        find $BACKUP_PATH -name "*dump.tar*" -type f -mtime +$DAYS_TO_KEEP -exec rm {} \;
      fi
  else
    find $BACKUP_PATH -name "dump.tar" -exec rm {} \;
  fi
}

function perform_backup {

  if [ $LOCK_WRITES -eq "1" ] ; then
    echo "db.fsyncLock()" | mongo $MONGO_HOST_PORT
  fi

  cd $BACKUP_PATH
  if [ -z "$DO_BACKUP" ] ; then
    cd $BACKUP_PATH
    log "$(date) starting mongodump (this will take a while)...." 
    $PERFORMANCE_THROTTLING $MONGO_DUMP -h $MONGO_HOST_PORT $MONGO_DUMP_OPTIONS
    if [ $? -ne 0 ] ; then
      log "ERROR -> mongo_dump failed to execute properly: err $?" ; ERR_RETURN="backup function : $LINENO : err $?"
      log "mongosback terminating early" 
      error_trap()
    fi
    tar --remove-files -cf $COMPRESSED_NAME dump/
  else
    log "$(date) starting mongodump (this will take a while)...." 
    $PERFORMANCE_THROTTLING $MONGO_DUMP -h $MONGO_HOST_PORT -d $DO_BACKUP -o $BACKUP_PATH $MONGO_DUMP_OPTIONS
    if [ $? -ne 0 ] ; then
      log "ERROR -> mongo_dump failed to execute properly: err $?" ; ERR_RETURN="backup function : $LINENO : err $?"
      log "mongosback terminating early" 
      error_trap()
    fi
    tar --remove-files -cf $COMPRESSED_NAME dump/
  fi

  log "mongodump successful, beginning post-dump operations" 
  if [ $LOCK_WRITES -eq "1" ] ; then
    echo "db.fsyncUnlock()" | mongo $MONGO_HOST_PORT
  fi
}

function ftp_export {

  if [ $FTP_EXPORT == "1" ] ; then
    ftp -n $FTP_HOST << EOF
      quote USER "$FTP_USER"
      quote PASS "$FTP_PASS"
      cd $FTP_PATH
      put $COMPRESSED_NAME
      quit
    EOF
      if [ $? -eq "1" ] ; then
        log "ERROR-> during ftp upload" ; ERR_RETURN="ftp_export function : $LINENO"
        error_trap()
      fi
  fi
}

function scp_export {

  if [ $SCP_EXPORT == "1" ] ; then
    scp $SCP_USER@$SCP_HOST:$SCP_PATH
  fi
}

function send_mail {

  if [ $EMAIL_REPORT -eq "1" ] ; then
    MB_SIZE=`du -hs $COMPRESSED_NAME`
    MB_HOST=`echo $MONGO_HOST_PORT | awk -F":" '{print $1}'`
    MB_ALL=`find $COMPRESS_STORE -name "*dump.tar*" -type f -exec du -hs {} \;`
      echo "backup host: $MB_HOST" >> mail.tmp
      echo "backup size:  $MB_SIZE" >> mail.tmp
      echo -e "disk usage:  (size : usage : avail : percent : parent) \n $(df -h $BACKUP_PATH | tail -n 1)" >> mail.tmp
      echo "backup time: $TIME_DIFF minutes" >> mail.tmp
      echo -e "Backups on hand\n$MB_ALL" >> mail.tmp
    EMAIL_SUBJECT="$MB_HOST - sucessful : $MB_SIZE : $TIME_DIFF minutes"
      /bin/mail -s "$EMAIL_SUBJECT" "$EMAIL_ADDRESS" < mail.tmp
        if [ $? -eq "0" ] ; then
          log "email notification successfully sent"
        fi
      rm -f mail.tmp
  fi
}

PID_FILE="/var/run/mongosback.pid"
# Define traps (excluding 'ERR')  
trap error_trap() SIGHUP SIGINT SIGTERM
echo "$$" > $PID_FILE
  START_TIME=$(date +%s)
  prepare_job()
  perform_backup()
  compress()
  archive()
  ftp_export()
  scp_export()
  END_TIME=$(date +%s)
  TIME_DIFF=$(( $END_TIME - $START_TIME ))
  TIME_DIFF=`echo $(($TIME_DIFF / 60 ))`
  log "finished mongodump in $TIME_DIFF minutes..." 
  send_mail()
rm -f $PID_FILE

echo "------------------------------------------------------------------------------------" >> $LOG_FILE

exit 0