#!/bin/bash
# BASH tutorial: http://www.faqs.org/docs/Linux-HOWTO/Bash-Prog-Intro-HOWTO.html#ss4.3
# Author: Chad Armstrong
# Created: 26 November 2007

#for i in $( ls ); do
#	echo item: $i
#done

mkdir tempfiles

COUNTER=0

while [ $COUNTER -lt 300 ]; do
	ls tempfiles >> tempfiles/$COUNTER.txt
	# echo The counter is $COUNTER
	let COUNTER=COUNTER+1
done
