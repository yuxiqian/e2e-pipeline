#!/bin/bash
#Cancels all the flink jobs. Run in the $FLINK_DIR/bin
#@Author: Aman Garg

echo -e "Cancelling all flink jobs"
echo -e "*************************"

JOB_LIST=$(./bin/flink list | awk {'print $4'} | grep -E '^\w+$')

for i in $JOB_LIST
    do
        ./bin/flink cancel "$i"
    done

echo -e "*************************"
echo -e "All jobs cancelled successfully"