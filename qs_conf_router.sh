#!/bin/bash


#*********** VARIABLES ***********#

wan=`ip r | grep default | grep -Po '(?<=dev )(\S+)'`     # name of router wan interface
lan=enp0s8               # name of router local interface

r_name=gate.test.net     # router hostname
h1_name=web100.test.net    # first web_server hostname
h2_name=web101.test.net    # second web_server hostname

r_ip=172.16.0.1          # router gateway IP
h1_ip=172.16.0.100       # first web_server IP
h2_ip=172.16.0.101       # second web_server IP

mask=16                  # prefix for local network




###################### Change router's hostname #########################

name_change() {

    hostnamectl set-hostname $r_name
}




###################### Disable selinux & firewalld ######################

dis_selin_firewd() {
    setenforce 0   # stoped selinux
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
    systemctl stop firewalld && systemctl disable firewalld
}




###################### Update yum & install yum plugin ##################

yum_conf() {
    yum update -y && yum install epel-release -y && yum install yum-plugin-remove-with-leaves -y
    sed -i 's/#exclude_bin = 1/exclude_bin = 0/' /etc/yum/pluginconf.d/remove-with-leaves.conf
    sed -i 's/#remove_always = 1/remove_always = 1/' /etc/yum/pluginconf.d/remove-with-leaves.conf
}




###################### Config Local network adapter #####################

conf_loc_net() {

    if [ -f "/etc/sysconfig/network-scripts/ifcfg-$lan" ]; then
        echo "------File $lan is alredy exists"
        echo "------Rewriting $lan configurating file"
        cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-$lan
TYPE="Ethernet"
PROXY_METHOD="none"
BROWSER_ONLY="no"
BOOTPROTO="none"
IPADDR=$r_ip
PREFIX=$mask
DEFROUTE="yes"
IPV4_FAILURE_FATAL="no"
NAME="$lan"
DEVICE="$lan"
ONBOOT="yes"
EOF
    else
        nmcli c add type ethernet con-name $lan ifname $lan ip4 $r_ip/$mask
    fi
}




################### Adding domain names to /etc/hosts ####################

hosts_conf(){    ##########Adding domain names to /etc/hosts
    
    cat <<EOF > /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
$r_ip    $r_name
$h1_ip  $h1_name
$h2_ip  $h2_name    
EOF

}




########################## Install puppet 5 ###############################

puppet_install() {

    rpm -Uvh https://yum.puppetlabs.com/puppet5/puppet5-release-el-7.noarch.rpm
    yum install puppet-agent -y
    cat<<EOF > /etc/puppetlabs/puppet/puppet.conf
# This file can be used to override the default puppet settings.
# See the following links for more details on what settings are available:
# - https://puppet.com/docs/puppet/latest/config_important_settings.html
# - https://puppet.com/docs/puppet/latest/config_about_settings.html
# - https://puppet.com/docs/puppet/latest/config_file_main.html
# - https://puppet.com/docs/puppet/latest/configuration.html

#[main]
#certname = $r_name
#server = $r_name
#autosign = true

[master]
vardir = /opt/puppetlabs/server/data/puppetserver
logdir = /var/log/puppetlabs/puppetserver
rundir = /var/run/puppetlabs/puppetserver
pidfile = /var/run/puppetlabs/puppetserver/puppetserver.pid
codedir = /etc/puppetlabs/code
EOF
    systemctl start puppet && systemctl enable puppet
}




############################# Install git ###############################

git_install() {

    yum install git -y
    git config --global user.name admin
    git config --global user.email admin@test.net
    git clone https://github.com /etc/puppetlubs/code/environments/
}




############################# Install r10k ##############################

r10k_install() {
    
    yum install rubygems -y && gem install r10k -v 2.6.5 -y
    
    
}

#########################################################################
############################------MAIN------#############################

name_change                      # change router's hostname
dis_selin_firewd                 # disable selinux and firewalld
yum_conf                         # update yum, install epel-release and remove-leaves plugin
conf_loc_net                     # create and config router local interface
hosts_conf                       # add names and ip-addresses to /etc/hosts
puppet_install                   # install and config puppet-server 5
#r10k_install                     # install rubygems & r10k tool
#git_install                      # install git
reboot
