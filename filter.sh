#!/bin/bash

function filter1 {
  for f in 201[0-9][0-9][0-9][0-9][0-9].htm; do
    sed '
      s|"/icons/file-pdf.png"|"/agh/icons/file-pdf.png"|g
      s|"Mwg-Kick-Type"|"agh-fly-type"|
      s|"/mwg3/mwg.kick.js"|"/agh/agh.fly.js"|
      s|"/mwg3/mwg.std.css"|"/agh/mwg.std.css"|
      s|"tex:math_bqd"|"aghfly-inline-math"|
      /"agh-fly-type"/i \  <meta name="aghfly-reverts-symbols" content="1" />
    ' "$f" > a.tmp &&
      ! diff -q "$f" a.tmp &>/dev/null &&
      touch -r "$f" a.tmp &&
      mv -fb a.tmp "$f"
  done
}

for d in 2012?? 2013{01..09}; do
  echo $d
  (cd $d; filter1)
done
