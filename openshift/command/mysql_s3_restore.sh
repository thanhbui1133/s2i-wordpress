#!/bin/bash

# Basic variables

aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"

mysqlpass="$MYSQL_PASSWORD"
mysqlname="$MYSQL_NAME"
mysqluser="$MYSQL_USER"
mysqlhost="$MYSQL_HOST"
mysqlport="$MYSQL_PORT"
siteurl="$SITE_URL"
object="$AWS_BUCKET_PATH"

echo Getting object from "$object"

aws s3 cp "$object" "backup.sql"

if [ $? -eq 0 ]; then
    echo Download OK
	mysqladmin -u $mysqluser -P $mysqlport -h $mysqlhost -p$mysqlpass --force drop $mysqlname

	mysqladmin -u $mysqluser -P $mysqlport -h $mysqlhost -p$mysqlpass --force create $mysqlname
	
	if [ $? -eq 0 ]; then
		mysql -u $mysqluser -P $mysqlport -h $mysqlhost -p$mysqlpass --force $mysqlname < backup.sql &
		
		BACK_PID=$!
		wait $BACK_PID
		
		# Delete
		rm -f "backup.sql"
		
		sleep 2m
		
		if [ "$siteurl" != "" ]; then
			mysql -u $mysqluser -P $mysqlport -h $mysqlhost -p$mysqlpass --force -D $mysqlname -e "UPDATE wp_options SET option_value = '$siteurl' where option_name = 'siteurl' or option_name = 'home'"
		fi
		echo Done
	else 
		echo FAILED to Import data;
		exit 2
	fi
 else
    echo FAILED Could not get "$object"
    exit 2
fi


