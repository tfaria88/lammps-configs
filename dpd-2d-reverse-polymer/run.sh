#! /bin/bash

set -e
set -u

for g in $(./genid.sh  list=g); do
	echo ${g}
done| parallel -j 1 -N1 --verbose ./runone.sh {1}
