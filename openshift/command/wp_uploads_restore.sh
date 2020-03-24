#!/bin/bash

# Note: /data/backup is the volume-mounted path to PVC (Persistent Volume Claim) to store backup files
# Note: /opt/app-root/wp-content is the volume-mounted path to PVC (Persistent Volume Claim) of the WordPress site (wp-content folder)

# Basic variables
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
            result=`echo "$result" | sed -r 's/[.tar.gz]+//g'`
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
    "s3") echo "Starting AWS S3 restore..."
        echo "Setup environment"
        aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
        aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"

        echo Checking url

        grep -e ".*\.tar.gz$" <<< $object

        if [ $? -ne 0 ]; then
            echo 'This is not a tar.gz file'
            if aws s3 ls "$object" 2>&1 | grep -q 'NoSuchBucket\|AllAccessDisabled'; then
                    >&2 echo This bucket does not exist or access denied
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
                            element=(`echo "$i" | awk "/[0-9]*_[0-9]*_[0-9]*_[0-9]*_[0-9]*_[0-9]*.tar.gz/"`)
                            filteredFile+=($element)
                        done
                        nearestfile="$(find_latest_bk $filteredFile)"
                        echo Found the latest file path: $object/$nearestfile
                        echo "Downloading..."
                        aws s3 cp "$object/$nearestfile" "wp-uploads.tar.gz"
                        backuppath="wp-uploads.tar.gz"
                    fi
                fi
        else
            echo Getting object from "$object"

            aws s3 cp "$object" "wp-uploads.tar.gz"

            if [ $? -eq 0 ]; then
              backuppath="wp-uploads.tar.gz"
              echo "  Download successful!"
            else
                IFS="/"
                read -ra ADDR <<< "$object"
                len=${#ADDR[@]}
                unset IFS
                bucketstr="s3://"
                filename=${ADDR[${#ADDR[@]}-1]}
                targettime=`echo "$filename" | sed -r 's/[.tar.gz]+//g'`
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
                    echo FAILED Could not get "wp-uploads.tar.gz" from S3 "$object". Finding the latest backup at "$bucketstr"
                    dirbackup=(`aws s3 ls "$bucketstr" | awk '{ print $4 }'`)
                    if [ ${#dirbackup[@]} -eq 0 ]; then
                        >&2 echo 'No file found'
                        exit 1
                    else
                        filteredFile=()
                        for i in ${dirbackup[@]}; do
                            element=(`echo "$i" | awk "/[0-9]*_[0-9]*_[0-9]*_[0-9]*_[0-9]*_[0-9]*.tar.gz/"`)
                            filteredFile+=($element)
                        done
                        nearestfile="$(find_latest_bk $filteredFile $targetstamp)"
                        echo Found the latest path: $bucketstr$nearestfile
                        echo "Downloading..."
                        aws s3 cp "$bucketstr$nearestfile" "wp-uploads.tar.gz"
                        backuppath="wp-uploads.tar.gz"
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
                echo Checking location to find a backup file to restore
                grep -e ".*\.tar.gz$" <<< $location
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
                    targettime=`echo "  $filename" | sed -r 's/[.tar.gz]+//g'`
                    IFS="_"
                    read -ra FILE_DATE <<< "$targettime"
                    unset IFS
                    targettime="${FILE_DATE[0]}/${FILE_DATE[1]}/${FILE_DATE[2]} ${FILE_DATE[3]}:${FILE_DATE[4]}:${FILE_DATE[5]}"
                    targetstamp=`date -d "$targettime" +"%s"`
                    echo "  Finding the nearest backup..."
                else
                    targetstamp=""
                    echo "  Finding the latest backup..."
                    location_temp=$location
					if [[ "$location_temp" != */ ]]; then
						location_temp+="/"
					fi
                fi
            fi
            if [ $? -eq 0 ]; then
                cd /data/backup/$location_temp
                now=`date +"%s"`
                dirbackup=(`ls -d [0-9]*_[0-9]*_[0-9]*_[0-9]*_[0-9]*.tar.gz`)
                if (( ${#dirbackup[@]} > 0 )); then
                    nearest=""
                    nearestfile="$(find_latest_bk $dirbackup $targetstamp)"
                    backuppath="/data/backup/$location_temp$nearestfile"
                    echo Found file: $backuppath
                else
                    >&2 echo "No backup file in the directory"
                    exit 1
                fi
            else
                >&2 echo "Wrong file format"
                exit 1
            fi

        else
            echo "Backup file found!"
            backuppath=$location
        fi
        ;;
    *) >&2 echo "Method is none or invalid"
	    exit 2
		;;
    esac
if [ $? -eq 0 ]; then
    echo "Extracting $backuppath to temporary /tmp/wp-uploads"
    mkdir /tmp/wp-uploads
    tar xvf $backuppath -C /tmp/wp-uploads

	if [ $? -eq 0 ]; then
        echo Dropping the current uploads folder
	    rm -rf /opt/app-root/wp-content/uploads

        echo "Moving uploads from /tmp/uploads"
        mv "/tmp/wp-uploads" "/opt/app-root/wp-content/uploads"

		BACK_PID=$!
		wait $BACK_PID

		echo Done restoring uploads folder
	else
		>&2 echo FAILED to Import data;
		exit 3
	fi
fi
