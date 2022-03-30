#!/bin/bash
#
# A script to create a testvm on openstack.
#
# requirements:
#    `apt install python3-openstackclient jq`
# or alternatively install openstack client via pip:
#    `pip install python openstackclient`
#
# Alternative plan: instead of
# creating new vm everytime, create one beforehand and boot from a snapshot
# everytime we want to run a test.

export APPCONFIG_DIR="$HOME/work/appconfig/apps"

# logfile. leave empty to disable logging
LOGFILE=./server_creation.log

# ---- User authentication.
# cf. https://docs.openstack.org/python-openstackclient/latest/cli/man/openstack.html

# These should probably set beforehand as environment variables.  Authentication
# can also be configured in ~/.config/openstack
## OS_AUTH_URL=<url-to-openstack-identity>
## OS_PROJECT_NAME=<project-name>
## OS_USERNAME=<user-name>
## OS_PASSWORD=<password>  # (optional)
# As an alternative one could use a service token
## OS_URL
## OS_TOKEN

# ---- Server setup configuration
# cf. https://docs.openstack.org/nova/xena/user/launch-instances.html

# Specify the flavor id
# You can get a list of all available flavors using `openstack flavor list`
FLAVOR_ID=

# Specify the image id.
# You can get a list of all available images using `openstack image list`
IMAGE_ID=

# Specify the name of the security group.
# `openstack security group list`
SEC_GROUP_NAME=

# Specify the keypair
# `openstack keypair list`
KEYNAME=

# What should be the name of the instance?
INSTANCE_NAME=testserver

# ---- Create the server
# cf. https://docs.openstack.org/nova/xena/user/launch-instances.html

echo "creating server" | tee $LOGFILE
SERVER_ID=$(openstack server create \
                      -f json \
                      --flavor $FLAVOR_ID \
                      --image $IMAGE_ID \
                      --key-name $KEY_NAME \
                      --security-group $SEC_GROUP_NAME \
                      --wait \
                      "$INSTANCE_NAME" \
                | tee -a $LOGFILE \
                | jq '.id'
         )


# You can check if the server was created using `openstack server list`

# TODO: check if we need to create a volume.  My guess is no as we don't need
# persistent storage.
# cf. https://docs.openstack.org/nova/xena/user/launch-instance-from-volume.html

# ---- Associate an IP address
# cf. https://docs.openstack.org/nova/xena/user/manage-ip-addresses.html

# allocate an ip address
# TODO: check if extraction of ip address works

echo "allocating ip address" | tee -a $LOGFILE
IP_ADDRESS=$(openstack floating ip create -f json  "public" \
                 | tee -a $LOGFILE \
                 | jq '.floating_ip.ip')

# get port id
echo "get portid" | tee -a $LOGFILE
PORT_ID=$(openstack port list -f json --device-id $SERVER_ID \
              | tee -a $LOGFILE \
              | jq '.interfaceAttachments[0].port_id'
       )

# associate ip with port
echo "associate ip with port" | tee -a $LOGFILE
openstack floating ip set --port $PORT_ID $IP_ADDRESS | tee -a $LOGFILE


# ---- Do the deployment

openstack server start $SERVER_ID

# setup server
cd "$APPCONFIG_DIR/../servers/app-server-setup/"
fab -H $IP_ADDRESS setup_server

# to test in testing environment, we need a domain name first, otherwise
# letsencrypt won't work.
#
# This part is still interactive.  We might need to adjust the code of
# clldappconfig to be able to script sudo password etc.  Also `-H` doesn't work
# yet for the testing environment.
cd "$APPCONFIG_DIR/wals3/wals3/"
fab -u cloud -H $IP_ADDRESS deploy:staging

# maybe do some tests here, eg.
# curl -u wals3:wals3 $IP_ADDRESS


# ---- Cleanup

openstack server stop $SERVER_ID
openstack floating ip delete $IP_ADDRESS
openstack server delete $SERVER_ID
