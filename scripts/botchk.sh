#!/bin/sh

BOTDIR=/home/apt/bot
BOTNICK=infobot
PIDFILE=$BOTDIR/$BOTNICK.pid

if [ -f $PIDFILE ]; then	# exists.
    PID=`cat $PIDFILE`
    if [ -d /proc/$PID ]; then	# already running.
	exit 0
    fi

    # infobot removes the pid file.
    echo "stale pid file; removing."
#    rm -f $PIDFILE
fi

cd $BOTDIR
./infobot

# vim:ts=4:sw=4:expandtab:tw=80
