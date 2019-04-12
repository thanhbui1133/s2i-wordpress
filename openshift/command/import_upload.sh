#!/bin/bash

# Basic variables

aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"

object="$AWS_BUCKET_PATH"

echo Getting object from "$object"

cd /opt/app-root/wp-content

aws s3 cp "$object" "uploads.tar" &

BACK_PID=$!

wait $BACK_PID

tar -xvf uploads.tar uploads



