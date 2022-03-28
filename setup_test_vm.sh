#!/bin/bash
#
# A script to create a testvm on openstack.  Alternative plan: instead of
# creating new vm everytime, create one beforehand and boot from a snapshot
# everytime we want to run a test

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
INSTANCE_NAME=

# ---- Create the server
# cf. https://docs.openstack.org/nova/xena/user/launch-instances.html

openstack server create \
		  --flavor $FLAVOR_ID \
		  --image $IMAGE_ID \
		  --key-name $KEY_NAME \
		  --security-group $SEC_GROUP_NAME \
		  "$INSTANCE_NAME"

# You can check if the server was created using `openstack server list`

# TODO: check if we need to create a volume.  My guess is no as we don't need
# persistent storage.
# cf. https://docs.openstack.org/nova/xena/user/launch-instance-from-volume.html

# ---- Associate an IP address
# cf. https://docs.openstack.org/nova/xena/user/manage-ip-addresses.html

# allocate an ip address
# TODO: check if extraction of ip address works
IP_ADDRESS=`openstack floating ip create public | grep floating_ip_address | grep -oP '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'`

# get server id
# TODO: extract id from output
## SERVER_ID=`openstack server list --instance-name "$INSTANCE_NAME" | so_some_grep_magic`

# get port id
## PORT_ID=`openstack port list --device-id $SERVER_ID | do_some_grep_magic`

# associate ip with port
openstack floating ip set --port $PORT_ID $IP_ADDRESS


# ---- Cleanup

openstack server stop $SERVER_ID
openstack floating ip delete $IP_ADDRESS
openstack server delete $SERVER_ID
