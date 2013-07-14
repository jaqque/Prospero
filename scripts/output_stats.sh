#!/bin/sh
echo -n "DEBUG:  "; grep DEBUG `find infobot src -type f`| wc -l
echo -n "WARN:   "; grep WARN `find infobot src -type f` | wc -l
echo -n "FIXME:  "; grep FIXME `find infobot src -type f` | wc -l
echo -n "status: "; grep status `find infobot src -type f` | wc -l
echo -n "ERROR:  "; grep ERROR `find infobot src -type f` | wc -l
echo -n "TODO:   "; grep TODO `find infobot src -type f` | wc -l

# vim:ts=4:sw=4:expandtab:tw=80
