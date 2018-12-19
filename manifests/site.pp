
###############################################################################
#                                VARIABLES                                    #

$tcat_user = lookup ('tcat_user')
$tcat_pass = lookup ('tcat_pass')

$stats_auth = lookup ('stats_auth')

$backend_options = lookup ('backend_options')
$options_quantity = lookup ('webservers_quantity') + 1
$options_values = $backend_options[0, $options_quantity]



################################################################################

node gate.test.net {

  class { '::haproxy':
    enable           => true,
    global_options   => {
        'log'     => '127.0.0.1 local2',
        'chroot'  => '/var/lib/haproxy',
        'pidfile' => '/var/run/haproxy.pid',
        'maxconn' => '4000',
        'user'    => 'haproxy',
        'group'   => 'haproxy',
        'daemon'  => '',
        'stats'   => 'socket /var/lib/haproxy/stats',
        },
    defaults_options => {
        'mode'    => 'http',
        'log'     => 'global',
        'stats'   => 'enable',
        'option'  => [
                      'redispatch',
                      'httplog',
                      'dontlognull',
                      'http-server-close',
                      'forwardfor except 127.0.0.0/8',
                      ],
        'retries' => '3',
        'timeout' => [
                      'http-request 10s',
                      'queue 1m',
                      'connect 10s',
                      'client 1m',
                      'server 1m',
                      'check 10s',
                    ],
        'maxconn' => '8000',
    },
  }
    haproxy::listen { 'stats':
    bind    => {'*:8090' => []},
    mode    => http,
    options => [
      {'stats' => 'enable'},
      {'stats' => 'hide-version'},
      {'stats' => 'show-node'},
      {'stats' => 'uri /stats'},
      {'stats' => $stats_auth},
      {'stats' => "refresh 5s" },
    ],
  }
    haproxy::frontend { 'tomcat':
        ipaddress     => '*',
        ports         => '80',
        mode          => 'http',
        options       => {
            'default_backend' => 'www',
        },
    }
    haproxy::backend { 'bk1':
        name          => 'www',
        mode          => 'http',
        options       => $options_values,
    }

}


######################################################################################

node /web\d+\.test\.net/ {


# Install java

    package { 'java-openjdk':
        ensure => 'installed'
    }



# Install tomcat
    class { 'tomcat':
        install_from => 'archive',
        version      => '7.0.86',
        admin_webapps        => true,
        create_default_admin => true,
        admin_user           => $tcat_user,
        admin_password       => $tcat_pass
    }

# add ntp client:
    class { 'ntp':
    servers => ['gate.test.net'],
    burst  => true,
    restrict  => [
        'default ignore',
#        '-6 default ignore',
        '127.0.0.1',
        "${facts['networking']['ip']}/16",
#        '-6 ::1',
        'gate.test.net nomodify notrap nopeer noquery'
    ],
    }


# Install maven

    package { 'maven':
        ensure => 'installed'
    }


}
