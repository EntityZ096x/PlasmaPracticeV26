#!/bin/bash
while true
do
    java -Xms4G -Xmx8G -jar server.jar nogui
    echo "Server stopped. Restarting in 5 seconds..."
    sleep 5
done