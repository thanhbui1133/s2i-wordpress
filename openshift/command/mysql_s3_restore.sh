#!/bin/bash

# Basic variables
mysqlpass="$MYSQL_PASSWORD"
mysqlname="$MYSQL_NAME"
mysqluser="$MYSQL_USER"
mysqlhost="$MYSQL_HOST"
mysqlport="$MYSQL_PORT"
siteurl="$SITE_URL"
object="$AWS_BUCKET_PATH"
location="$LOCATION"
method="$METHODS"
backuppath=""

case "$method" in
    "s3") echo "Starting s3 restore..."
        echo "Setup environment"
        aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
        aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"

        echo Getting object from "$object"

        aws s3 cp "$object" "backup.sql"

        if [ $? -eq 0 ]; then
          backuppath="backup.sql"
          echo "  Download successful!"
        else
          echo FAILED Could not get from s3 "backup.sql" from "$object"
          exit 2
        fi
        ;;
    "pvc") echo "Starting pvc restore..."
        if [ ! -f location ]; then
            echo "Backup file not found! Finding lastest backup..."
            cd /data/backup
            now=`date +"%s"`
            nearest=$now
            nearestfolder=""
            dirbackup=(`ls /data/backup`)
            for i in "${dirbackup[@]}"; do
                result=`echo "$i" | sed -r 's/[_]+/\//g'`
                timestamptemp=`date -d $result +"%s"`
                if [ $nearest -gt $timestamptemp ]; then
                    nearest=$timestamptemp
                    nearestfolder=$i
                fi
            done
            cd $nearestfolder
            filebackup=(`ls`)
            nearest=${filebackup[0]}
            for i in "${filebackup[@]}"; do
                result=`echo "$i" | sed -r 's/[_]+/:/g'`
                result=`echo "$result" | sed -r 's/[.sql]+//g'`
                result+=":00"
                timestamptemp=`date -d $result +"%s"`
                if [ $timestamptemp -gt $nearest ]; then
                    nearest=$timestamptemp
                    nearestfile=$i
                fi
            done
            backuppath="$nearestfolder/$nearestfile"
        else
            echo "Backup file found"
            backuppath=$location
        fi
        echo
        ;;
    *) echo "Method is none or invalid"
	    exit 2
		;;
    esac

#if [ $? -eq 0 ]; then
#    echo Download OK
#	/opt/rh/rh-mysql57/root/usr/bin/mysqladmin -u $mysqluser -P $mysqlport -h $mysqlhost -p$mysqlpass --force drop $mysqlname
#
#	/opt/rh/rh-mysql57/root/usr/bin/mysqladmin -u $mysqluser -P $mysqlport -h $mysqlhost -p$mysqlpass --force create $mysqlname
#
#	if [ $? -eq 0 ]; then
#		/opt/rh/rh-mysql57/root/usr/bin/mysql -u $mysqluser -P $mysqlport -h $mysqlhost -p$mysqlpass --force $mysqlname < backup.sql &
#
#		BACK_PID=$!
#		wait $BACK_PID
#
#		# Delete
#		rm -f "backup.sql"
#
#		sleep 2m
#
#		if [ "$siteurl" != "" ]; then
#			/opt/rh/rh-mysql57/root/usr/bin/mysql -u $mysqluser -P $mysqlport -h $mysqlhost -p$mysqlpass --force -D $mysqlname -e "UPDATE wp_options SET option_value = '$siteurl' where option_name = 'siteurl' or option_name = 'home'"
#		fi
#		echo Done
#	else
#		echo FAILED to Import data;
#		exit 3
#	fi
#fi


