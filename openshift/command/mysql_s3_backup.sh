#!/bin/bash

# Basic variables

mysqlpass="$MYSQL_PASSWORD"
mysqlname="$MYSQL_NAME"
mysqluser="$MYSQL_USER"
mysqlhost="$MYSQL_HOST"
mysqlport="$MYSQL_PORT"
bucket="$AWS_BUCKET"
methods="$METHODS"
folder="$LOCATION_STORAGE"
daytodel="$DAYTODEL"

#stamp=`date +"%s_%A_%d_%B_%Y_%H%M"`
stamp=`date +"%m_%d_%Y_%H_%M_%S"`

location="$folder/$stamp.sql"

datediff() {
    d1=$(date -d "$1" +%s)
    d2=$(date -d "$2" +%s)
    echo $(( (d1 - d2) / 86400 ))
}

/opt/rh/rh-mysql57/root/usr/bin/mysqldump -u $mysqluser -P $mysqlport -h $mysqlhost -p$mysqlpass $mysqlname > backup.sql;

if [ $? -eq 0 ]; then
  echo Dump database $mysqlname ok
else
  echo FAILED Could not mysqldump database $mysqlname to "backup.sql"
  exit 1
fi

IFS=","

len=${#methods[@]}
echo Found $len method:

for (( i=0; i<$len; i++ )); do echo "- ${methods[$i]}\n" ; done

read -ra methodsArr <<< "$methods"
unset IFS

for i in "${methodsArr[@]}"; do
    case "$i" in
        "s3") echo "Starting s3 backup..."

        echo "Setup environment"
        aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
        aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
        object="$bucket/$location"

        echo -e " uploading..."
        aws s3 cp "backup.sql" "$object"

        if [ $? -eq 0 ]; then
          echo "  Upload successful!"
        else
          echo FAILED Could not aws s3 cp "backup.sql" "$object"
          exit 2
        fi

        if [ $? -eq 0 ]; then
          if [ -z $daytodel ]; then
            echo "Can't found day duration"
          else
            echo "Check and deleting old file"
            list_time=(`aws s3 ls "$bucket/$folder" | awk '{ print $4 }'`)
            if [ ${#list_time[@]} -eq 0 ]; then
              echo 'No file found'
            else
              filteredFile=()
              for i in ${list_time[@]}; do
                element=(`echo "$i" | awk "/[0-9]*_[0-9]*_[0-9]*_[0-9]*_[0-9]*_[0-9]*.sql/"`)
                element=`echo "$element" | sed -r 's/[.sql]+//g'`
                filteredFile+=($element)
              done
              now=`date +"%m/%d/%Y %H:%M:%S"`
              for i in ${filteredFile[@]}; do
                IFS="_"
                read -ra FILE_DATE <<< "$i"
                unset IFS
                targettime="${FILE_DATE[0]}/${FILE_DATE[1]}/${FILE_DATE[2]} ${FILE_DATE[3]}:${FILE_DATE[4]}:${FILE_DATE[5]}"
                duration=`datediff $targettime $now`
                if [ $duration -lt -10 ]; then
                    aws s3 rm "$bucket/$folder/$i.sql"
                fi
              done
            fi
          fi
        fi

        ;;
        "pvc") echo "Starting pvc backup..."
        if [ ! -d "/data/backup/$folder" ]; then
            mkdir "/data/backup/$folder"
        fi
        mv "backup.sql" "/data/backup/$location"
        if [ $? -eq 0 ]; then
          echo " Backup successful"
        else
          echo FAILED Could not move "backup.sql" to specific folder
          exit 2
        fi

        # Delete old files
        if [ $? -eq 0 ]; then
          echo "Check and deleting old file"
          if [ -z $daytodel ]; then
            echo "Can't found day duration"
          else
            find "/data/backup/$folder" -type f -name '*.sql' -mtime +"$daytodel" -exec rm {} \;
            if [ $? -eq 0 ]; then
              echo OK Deleted old files in "/data/backup/$folder" before "$daytodel"
            else
              echo FAILED Could not delete old files in "/data/backup/$folder" before "$daytodel"
              exit 2
            fi
          fi
        fi

        ;;
        *)
		  echo "Method is none or invalid"
		;;
    esac
done

unset IFS

# Delete
rm -f "backup.sql"

echo "Done"