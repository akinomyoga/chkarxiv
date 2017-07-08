#!/bin/bash

date=${1-`date +%Y%m%d`}

if test -f $date.htm; then
  echo "specified file already exists." >/dev/stderr
  exit 1
fi

sed s/20120301/$date/g template.htm > $date.htm
