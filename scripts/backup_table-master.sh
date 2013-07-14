#!/bin/bash

BACKUP_SRCDIR="/var/lib/mysql/"
BACKUP_TDIR="infobot/"
BACKUP_FILE="/home/a/apt/public_html/tables.tar.bz2"

pwd
echo "Copying... $BACKUP_SRCDIR/$BACKUP_TDIR"
cp -R $BACKUP_SRCDIR/$BACKUP_TDIR ~

if [ -d $BACKUP_TDIR ]; then
    echo "Tarring... $BACKUP_FILE $BACKUP_TDIR"
    tar -Icvf $BACKUP_FILE $BACKUP_TDIR
    echo "Removing..."
    rm -rf $BACKUP_TDIR
else
    echo "ERROR: $BACKUP_TDIR doesn't exist."
fi

exit 0;

# vim:ts=4:sw=4:expandtab:tw=80
