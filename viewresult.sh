#!/bin/bash
if [ $# -ne 1 ]; then
    echo "This script takes exactly 1 parameter, the .benchmark outputfile from benchmaster."
fi
#sed '/{/Q' $1 >temp.txt
sed -n '/{/,$ p' $1 >temp.json
python viewresult.py
rm temp.json
