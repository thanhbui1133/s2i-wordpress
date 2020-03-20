#!/bin/bash

# Note: /opt/app-root/wp-content is the volume-mounted path to PVC (Persistent Volume Claim) of the WordPress site (wp-content folder)
# Note: /data/backup is the volume-mounted path to PVC (Persistent Volume Claim) to store backup files

# Basic variables
folder="$LOCATION_BACKUP"
daytodel="$DAYTODEL"

#stamp=`date +"%s_%A_%d_%B_%Y_%H%M"`
stamp=`date +"%m_%d_%Y_%H_%M_%S"`

location="$folder/uploads_$stamp"

echo "Starting backup..."
if [ ! -d "/data/backup/$folder" ]; then
  mkdir "/data/backup/$folder"
fi

echo Copy "uploads" folder to the backup location
#https://linuxize.com/post/cp-command-in-linux/
if [ ! -d "/data/backup/$location" ]; then
  mkdir "/data/backup/$location"
fi
cp -rt "/opt/app-root/wp-content/uploads" "/data/backup/$location"
if [ $? -eq 0 ]; then
  echo " Backup successful"
else
  >&2 echo FAILED Could not copy "uploads" folder to the backup location
  exit 1
fi

# Delete old files
if [ $? -eq 0 ]; then
          echo "Check and deleting old file"
          if [ -z $daytodel ]; then
            >&2 echo " Can't find day duration"
          else
            find "/data/backup/$folder" -type d -name 'uploads_*' -mtime +"$daytodel" -exec rm -rf {} \;
            if [ $? -eq 0 ]; then
              echo OK Deleted old folders in "/data/backup/$folder" before "$daytodel" days from today
            else
              >&2 echo FAILED Could not delete old folders in "/data/backup/$folder" before "$daytodel" days from today
              exit 1
            fi
          fi
fi

>&1 echo "Done"