#!/bin/bash
#
# Print the SHAs used in all the stage jobs.
# If they all match then print just them, else print every job's used SHA
#

if [ $(grep ") cassandra" *.head | sort -k4 | uniq -f3 | sed -n '$=') -eq 3 ]; then
  echo "The folllowing SHAs were consistently used in all jobs in the pipeline…"
  grep ") cassandra" *.head | awk '{$1=$2=$3=""; print $0}' | sort -u
else
  echo "Different SHAs were used in different jobs in the pipeline. Printing everything…"
  grep ") cassandra" *.head
fi
