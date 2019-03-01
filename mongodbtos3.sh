#!/bin/sh

# Make sure to:
# 1) Name this file `mongodbtos3.sh` and place it in /home/ec2-user
# 2) Run pip install awscli --upgrade --user
# 3) Run aws configure (enter s3-authorized IAM user and specify region)
# 4) Fill in DB host + name
# 5) Create S3 bucket for the backups and fill it in below (set a lifecycle rule to expire files older than X days in the bucket)
# 6) Run chmod +x mongodbtos3.sh
# 7) Test it out via ./mongodbtos3.sh
# 8) Set up a daily backup at midnight via `crontab -e`:
#    0 0 * * * /home/ec2-user/mongodbtos3.sh > /home/ec2-user/mongodbtos3.log
#
#HOW TO RESTORE FROM BACKUP
#
#Download the .tar backup to the server from the S3 bucket via wget or curl:
#wget -O backup.tar https://s3.amazonaws.com/my-bucket/xx-xx-xxxx-xx:xx:xx.tar
#Alternatively, use the awscli to download it securely.
#Then, extract the tar archive:
#tar xvf backup.tar
#Finally, import the backup into a MongoDB host:
#mongorestore --host {db.example.com} --db {my-db} {db-name}/

export HOME=/home/ec2-user

# DB host (secondary preferred as to avoid impacting primary performance)
HOST=10.0.41.183

# DB name
DBNAME=admin

# S3 bucket name
BUCKET=phoenixmarco

# Linux user account
USER=ec2-user

# Current time
TIME=`/bin/date +%d-%m-%Y-%T`

# Backup directory
DEST=/home/$USER/tmp

# Tar file of backup directory
TAR=$DEST/../$TIME.tar

# Create backup dir (-p to avoid warning if already exists)
/bin/mkdir -p $DEST

# Log
echo "Backing up $HOST/$DBNAME to s3://$BUCKET/ on $TIME";

# Dump from mongodb host into backup directory
/usr/bin/mongodump -h $HOST -d $DBNAME -o $DEST

# Create tar of backup directory
/bin/tar cvf $TAR -C $DEST .

# Upload tar to s3
/usr/bin/aws s3 cp $TAR s3://$BUCKET/

# Remove tar file locally
/bin/rm -f $TAR

# Remove backup directory
/bin/rm -rf $DEST

# All done
echo "Backup available at https://s3.amazonaws.com/$BUCKET/$TIME.tar"
