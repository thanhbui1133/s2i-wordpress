#!/bin/bash

# Basic variables

mysqlpass="$MYSQL_PASSWORD"
mysqlname="$MYSQL_NAME"
mysqluser="$MYSQL_USER"
mysqlhost="$MYSQL_HOST"
mysqlport="$MYSQL_PORT"
bucket="$AWS_BUCKET"
methods="$METHODS"

#stamp=`date +"%s_%A_%d_%B_%Y_%H%M"`
stampdate=`date +"%m_%d_%Y"`
stamphour=`date +"%H_%M"`

location="$stampdate/$stamphour.sql"

/opt/rh/rh-mysql57/root/usr/bin/mysqldump -u $mysqluser -P $mysqlport -h $mysqlhost -u wordpress -p$mysqlpass $mysqlname > backup.sql;

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
        ;;
        "pvc") echo "Starting pvc backup..."
        if [ ! -d "/data/backup/$stampdate" ]; then
            mkdir "/data/backup/$stampdate"
        fi
        mv "backup.sql" "/data/backup/$stampdate/$stamphour.sql"
        if [ $? -eq 0 ]; then
          echo " Backup successful"
        else
          echo FAILED Could not move "backup.sql" to specific folder
          exit 2
        fi
        ;;
        *)
		  echo "Method is none or invalid"
		;;
    esac
done

IFS=" "

# Delete
rm -f "backup.sql"

echo "Done"