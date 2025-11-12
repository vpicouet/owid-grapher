set -ex

mysql -u vincent -p -e "CREATE DATABASE owid;"
echo test

curl -Lo /tmp/owid_metadata.sql.gz https://files.ourworldindata.org/owid_metadata.sql.gz
#gunzip < /tmp/owid_metadata.sql.gz | mysql -D owid
gunzip < /tmp/owid_metadata.sql.gz | mysql -u vincent -p -D owid
