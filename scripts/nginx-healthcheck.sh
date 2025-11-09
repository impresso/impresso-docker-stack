#!/bin/sh

# Successful conditions:
# Both of these pages should not return 404. If they do - it's a problem and Nginx should be restarted.
curl -V || apk add --no-cache curl
$(test $(curl --connect-timeout 3 -s -o /dev/null -w "%{http_code}" http://localhost/public-api/search) -ne 404) || \
$(test $(curl --connect-timeout 3 -s -o /dev/null -w "%{http_code}" http://localhost/api/socket.io/) -ne 404)
