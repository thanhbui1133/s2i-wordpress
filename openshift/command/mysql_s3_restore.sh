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

find_latest_bk() {
    if [ -z "$1" ]
    then
        >&2 echo No variable found
        exit 1
    else
        dirbackup=$1
        if [ -z "$2" ]; then
            nearest=""
        else
            nearest="$2"
        fi
        posMinOffsets=""
        negaMinOffsets=""
        for i in "${dirbackup[@]}"; do
            IFS="_"
            read -ra FILE_DATE <<< "$i"
            result="${FILE_DATE[0]}/${FILE_DATE[1]}/${FILE_DATE[2]} ${FILE_DATE[3]}:${FILE_DATE[4]}:${FILE_DATE[5]}"
            result=`echo "$result" | sed -r 's/[.sql]+//g'`
            stamptemp=`date -d "$result" +"%s"`
            if [ "$nearest" = "" ]; then nearest=`date +"%s"`; fi
            offsets=$(( $stamptemp - $nearest ))
            if [ "$offsets" -ge "0" ]; then
               if [ "$posMinOffsets" = "" ]; then posMinOffsets=$offsets; nearestPosfile=$i; fi
               if [ "$posMinOffsets" -gt "$offsets" ]; then
                    posMinOffsets=$offsets
                    nearestPosfile=$i
               fi
            else
               if [ "$negaMinOffsets" = "" ]; then negaMinOffsets=$offsets; nearestNegafile=$i; fi
               if [ "$negaMinOffsets" -lt "$offsets" ]; then
                    negaMinOffsets=$offsets
                    nearestNegafile=$i
               fi
            fi
            if [ "$nearestPosfile" = "" ]; then
                nearestfile=$nearestNegafile
            else
                nearestfile=$nearestPosfile
            fi
            unset IFS
        done
        echo $nearestfile
    fi
}

case "$method" in
    "s3") echo "Starting s3 restore..."
        echo "Setup environment"
        aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
        aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"

        echo Checking url

        grep -e ".*\.sql$" <<< $object

        if [ $? -ne 0 ]; then
            echo 'This is not a sql file'
            if aws s3 ls "$object" 2>&1 | grep -q 'NoSuchBucket\|AllAccessDisabled'; then
                    >&2 echo This bucket is not exist or access denied
                    exit 1
                else
                    echo Finding the latest backup at "$object"...
                    grep -e ".*\/$" <<< $object
                    if [ $? -ne 0 ]; then object+="/"; fi
                    dirbackup=(`aws s3 ls "$object" | awk '{ print $4 }'`)
                    if [ ${#dirbackup[@]} -eq 0 ]; then
                        >&2 echo 'No file found'
                        exit 1
                    else
                        filteredFile=()
                        for i in ${dirbackup[@]}; do
                            element=(`echo "$i" | awk "/[0-9]*_[0-9]*_[0-9]*_[0-9]*_[0-9]*_[0-9]*.sql/"`)
                            filteredFile+=($element)
                        done
                        nearestfile="$(find_latest_bk $filteredFile)"
                        echo Found the latest path: $object/$nearestfile
                        echo "Downloading..."
                        aws s3 cp "$object/$nearestfile" "backup.sql"
                        backuppath="backup.sql"
                    fi
                fi
        else
            echo Getting object from "$object"

            aws s3 cp "$object" "backup.sql"

            if [ $? -eq 0 ]; then
              backuppath="backup.sql"
              echo "  Download successful!"
            else
                IFS="/"
                read -ra ADDR <<< "$object"
                len=${#ADDR[@]}
                unset IFS
                bucketstr="s3://"
                filename=${ADDR[${#ADDR[@]}-1]}
                targettime=`echo "$filename" | sed -r 's/[.sql]+//g'`
                IFS="_"
                read -ra FILE_DATE <<< "$targettime"
                unset IFS
                targettime="${FILE_DATE[0]}/${FILE_DATE[1]}/${FILE_DATE[2]} ${FILE_DATE[3]}:${FILE_DATE[4]}:${FILE_DATE[5]}"
                targetstamp=`date -d "$targettime" +"%s"`
                if (( $(($len - 1)) <= 3 )); then
                    bucketstr+=${ADDR[2]}/
                else
                    for ((i=2;i<=$(($len - 2));i++)); do
                        bucketstr+=${ADDR[$i]}/
                    done
                fi
                if aws s3 ls "$bucketstr" 2>&1 | grep -q 'NoSuchBucket\|AllAccessDisabled'; then
                    >&2 echo This bucket is not exist or access denied
                    exit 1
                else
                    echo FAILED Could not get from s3 "backup.sql" from "$object". Finding latest backup at "$bucketstr"
                    dirbackup=(`aws s3 ls "$bucketstr" | awk '{ print $4 }'`)
                    if [ ${#dirbackup[@]} -eq 0 ]; then
                        >&2 echo 'No file found'
                        exit 1
                    else
                        filteredFile=()
                        for i in ${dirbackup[@]}; do
                            element=(`echo "$i" | awk "/[0-9]*_[0-9]*_[0-9]*_[0-9]*_[0-9]*_[0-9]*.sql/"`)
                            filteredFile+=($element)
                        done
                        nearestfile="$(find_latest_bk $filteredFile $targetstamp)"
                        echo Found the latest path: $bucketstr$nearestfile
                        echo "Downloading..."
                        aws s3 cp "$bucketstr$nearestfile" "backup.sql"
                        backuppath="backup.sql"
                    fi
                fi
            fi
        fi
        ;;
    "pvc") echo "Starting pvc restore..."
        if [[ ! -f "/data/backup/"$location || "$location" = "" ]]; then
            echo "Backup file not found!"
            location_temp=""
            if [ "$location" = "" ]; then
                >&2 echo "Invalid input"
                exit 1
            else
                echo Checking location
                grep -e ".*\.sql$" <<< $location
                if [ $? -eq 0 ]; then
                    IFS="/"
                    read -ra ADDR <<< "$location"
                    unset IFS
                    filename=${ADDR[${#ADDR[@]}-1]}
                    for i in ${ADDR[@]}; do
                        if [ $i != $filename ]; then
                            location_temp+=$i
                            location_temp+="/"
                        fi
                    done
                    targettime=`echo "$filename" | sed -r 's/[.sql]+//g'`
                    IFS="_"
                    read -ra FILE_DATE <<< "$targettime"
                    unset IFS
                    targettime="${FILE_DATE[0]}/${FILE_DATE[1]}/${FILE_DATE[2]} ${FILE_DATE[3]}:${FILE_DATE[4]}:${FILE_DATE[5]}"
                    targetstamp=`date -d "$targettime" +"%s"`
                    echo "Finding the nearest backup..."
                else
                    targetstamp=""
                    echo "Finding the lastest backup..."
                    location_temp=$location
                fi
            fi
            if [ $? -eq 0 ]; then
                cd /data/backup/$location_temp
                now=`date +"%s"`
                dirbackup=(`ls -d [0-9]*_[0-9]*_[0-9]*_[0-9]*_[0-9]*.sql`)
                if (( ${#dirbackup[@]} > 0 )); then
                    nearest=""
                    nearestfile="$(find_latest_bk $dirbackup $targetstamp)"
                    backuppath="/data/backup/$location_temp$nearestfile"
                    echo Found path: $backuppath
                else
                    >&2 echo "No backup file at directory"
                    exit 1
                fi
            else
                >&2 echo "Wrong file format"
                exit 1
            fi

        else
            echo "Backup file found"
            backuppath=$location
        fi
        ;;
    *) >&2 echo "Method is none or invalid"
	    exit 2
		;;
    esac
if [ $? -eq 0 ]; then

	/opt/rh/rh-mysql57/root/usr/bin/mysqladmin -u $mysqluser -P $mysqlport -h $mysqlhost -p$mysqlpass --force drop $mysqlname

	/opt/rh/rh-mysql57/root/usr/bin/mysqladmin -u $mysqluser -P $mysqlport -h $mysqlhost -p$mysqlpass --force create $mysqlname

	if [ $? -eq 0 ]; then
		/opt/rh/rh-mysql57/root/usr/bin/mysql -u $mysqluser -P $mysqlport -h $mysqlhost -p$mysqlpass --force $mysqlname < $backuppath &

		BACK_PID=$!
		wait $BACK_PID

		if [ "$siteurl" != "" ] && [ "$siteurl" != "none" ]; then
			/opt/rh/rh-mysql57/root/usr/bin/mysql -u $mysqluser -P $mysqlport -h $mysqlhost -p$mysqlpass --force -D $mysqlname -e "UPDATE wp_options SET option_value = '$siteurl' where option_name = 'siteurl' or option_name = 'home'"
		fi
		echo Done
	else
		>&2 echo FAILED to Import data;
		exit 3
	fi
fi


