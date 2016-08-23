#!/bin/bash

echo $(date) " - Starting Script"

set -e

SUDOUSER=$1
PASSWORD=$2
PRIVATEKEY=$3
MASTER=$4
MASTERPUBLICIPHOSTNAME=$5
MASTERPUBLICIPADDRESS=$6
NODEPREFIX=$7
NODECOUNT=$8
ROUTING=$9

DOMAIN=$( awk 'NR==2' /etc/resolv.conf | awk '{ print $2 }' )

# Generate private keys for use by Ansible
echo $(date) " - Generating Private keys for use by Ansible for OpenShift Installation"

echo "Generating keys"

runuser -l $SUDOUSER -c "echo \"-----BEGIN RSA PRIVATE KEY-----\" > ~/.ssh/id_rsa"
runuser -l $SUDOUSER -c "echo \"$PRIVATEKEY\" >> ~/.ssh/id_rsa"
runuser -l $SUDOUSER -c "echo \"-----END RSA PRIVATE KEY-----\" >> ~/.ssh/id_rsa"
runuser -l $SUDOUSER -c "chmod 600 ~/.ssh/id_rsa*"

echo "Configuring SSH ControlPath to use shorter path name"

sed -i -e "s/^# control_path = %(directory)s\/%%h-%%r/control_path = %(directory)s\/%%h-%%r/" /etc/ansible/ansible.cfg
sed -i -e "s/^#host_key_checking = False/host_key_checking = False/" /etc/ansible/ansible.cfg
sed -i -e "s/^#pty=False/pty=False/" /etc/ansible/ansible.cfg

# Create Ansible Hosts File
echo $(date) " - Create Ansible Hosts file"

cat > /etc/ansible/hosts <<EOF
# Create an OSEv3 group that contains the masters and nodes groups
[OSEv3:children]
masters
nodes

# Set variables common for all OSEv3 hosts
[OSEv3:vars]
ansible_ssh_user=$SUDOUSER
ansible_become=yes
deployment_type=openshift-enterprise
docker_udev_workaround=True
openshift_use_dnsmasq=no
openshift_master_default_subdomain=$ROUTING

openshift_master_cluster_public_hostname=$MASTERPUBLICIPHOSTNAME
openshift_master_cluster_public_vip=$MASTERPUBLICIPADDRESS

# Enable HTPasswdPasswordIdentityProvider
openshift_master_identity_providers=[{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider', 'filename': '/etc/origin/master/htpasswd'}]

# host group for masters
[masters]
$MASTER.$DOMAIN

# host group for nodes
[nodes]
$MASTER.$DOMAIN openshift_node_labels="{'region': 'infra', 'zone': 'default'}" openshift_schedulable=true
$NODEPREFIX-[1:${NODECOUNT}].$DOMAIN openshift_node_labels="{'region': 'primary', 'zone': 'default'}"
EOF

# for (( c=0; c<$NODECOUNT; c++ ))
# do
#   echo "$NODEPREFIX-$c.$DOMAIN" >> /etc/ansible/hosts
# done

echo $(date) " - Script complete"
