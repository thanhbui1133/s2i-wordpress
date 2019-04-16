#!/bin/bash

# Basic variables

aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KE"

mysqlpass="$MYSQL_PASSWORD"
mysqlname="$MYSQL_NAME"
mysqluser="$MYSQL_USER"
mysqlhost="$MYSQL_HOST"
mysqlport="$MYSQL_PORT"
bucket="$AWS_BUCKET"

stamp=`date +"%s_%A_%d_%B_%Y_%H%M"`

object="$bucket/$stamp/backup.sql"

/opt/rh/rh-mysql57/root/usr/bin/mysqldump -u $mysqluser -P $mysqlport -h $mysqlhost -u wordpress -p$mysqlpass $mysqlname > backup.sql;

methods="$METHODS"

IFS=","

read -ra methodsArr <<< "$methods"

for i in "${methodsArr[@]}"; do
    case "$i" in
        "s3") echo "Starting s3 backup..."
        if [ $? -eq 0 ]; then
          echo OK
        else
          echo FAILED Could not mysqldump "backup.sql"
          exit 1
        fi

        echo -e "  uploading..."
        aws s3 cp "backup.sql" "$object"

        if [ $? -eq 0 ]; then
          echo OK
        else
          echo FAILED Could not aws s3 cp "backup.sql" "$object"
          exit 2
        fi
        ;;
        "pvc") echo "Starting pvc backup..."
        mv "backup.sql" "/data/backup/$stamp/backup.sql"
        ;;
    esac
done



# Delete
rm -f "backup.sql"

echo "Done"