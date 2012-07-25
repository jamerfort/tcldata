#!/bin/bash

find tests -name \*.rspec | while read F
do
	echo "### $F ###"
	rspec --color "$F"
	echo ""
done
