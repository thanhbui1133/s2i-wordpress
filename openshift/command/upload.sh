#!/bin/bash

# Basic variables

if [ "$AWS_ACCESS_KEY_ID" != "" ]
then
    if [ -d "/opt/app-root/src/wp-content/uploads" ]
    then
        aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
        aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
        aws s3 cp "$AWS_FILE_UPLOAD_PATH" "upload.tar" = &
        BACK_PID=$!
        wait $BACK_PID
        tar -xvf upload.tar uploads
    fi
fi