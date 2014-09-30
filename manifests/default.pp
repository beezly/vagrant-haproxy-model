node default {
  
  include apt
  
  apt::ppa { 'ppa:vbernat/haproxy-1.5': }
  
  openssl::certificate::x509 { 'test.site':
    ensure       => present,
    country      => 'GB',
    organization => 'Some Organisation',
    commonname   => 'test.site',
    base_dir     => '/etc/ssl/private/',
    owner        => 'www-data',
  }
  
  file { "/etc/haproxy/ssl":
    ensure  => 'directory',
    owner   => 'haproxy',
    group   => 'haproxy',
    mode    => '0700',
    require => Package["haproxy"],    
  }
  
  concat { "/etc/haproxy/ssl/test.site.key":
    owner   => 'haproxy',
    group   => 'haproxy',
    mode    => '400',
    require => [File["/etc/haproxy/ssl"],Openssl::Certificate::X509['test.site']],
    notify  => Service['haproxy'],
  }

  concat::fragment { 'test.site.crt':
    target  => '/etc/haproxy/ssl/test.site.key',
    source  => '/etc/ssl/private/test.site.crt',
    order   => '01',
  }
  
  concat::fragment { 'test.site.key':
    target => '/etc/haproxy/ssl/test.site.key',
    source => '/etc/ssl/private/test.site.key',
    order  => '02', 
  }
  
  class { 'nginx': 
    require => Openssl::Certificate::X509['test.site'],
  }
  
  class {'haproxy':
    require => Apt::Ppa['ppa:vbernat/haproxy-1.5'],
  }
  
  haproxy::frontend{'ft_spdy':
    ports => '8080',
    ipaddress => '0.0.0.0',
    bind_options => [
      'name https',
      'ssl crt /etc/haproxy/ssl/test.site.key',
      'npn spdy/3.1,http/1.1'
    ],
    options => {
      'default_backend' => 'http_cluster',
      'use_backend'     => 'spdy_cluster if { ssl_fc_npn -i spdy/3.1 }',      
    },
  }
  
  haproxy::backend{'http_cluster':
    options => {
      'mode'   => 'http',
    },
    collect_exported => false,
  }
  
  haproxy::backend{'spdy_cluster':
    collect_exported => false,
  }
  
  haproxy::balancermember{'localhost_http':
    listening_service => 'http_cluster',
    server_names      => $::hostname,
    ipaddresses       => $::ipaddress,
    ports             => '8081',
  }
  
  haproxy::balancermember{'localhost_spdy':
    listening_service => 'spdy_cluster',
    server_names      => $::hostname,
    ipaddresses       => $::ipaddress,
    ports             => '8082',
  }
  
  haproxy::listen{'stats':
    collect_exported => false,
    ports => '8099',
    options => {
      'mode'        => 'http',
      'stats'       => 'enable',
      'stats uri'   => '/',
      'stats auth'  => 'test:site',
      'stats realm' => 'Stats',
    }
  }
  
  $packages = hiera("packages")
  
  package {$packages:
    ensure => "present",
  }
}