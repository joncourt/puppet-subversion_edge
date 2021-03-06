class subversion_edge($repo, 
                      $version, 
                      $user = "maestro", 
                      $home = "/home/maestro", 
                      $group = "maestro", 
                      $jdk = "java-1.6.0-openjdk") {
  include wget
  
  $download_url = "https://repo.maestrodev.com/archiva/repository/3rdparty/com/collabnet/subversion-edge/${version}" #https://repo.maestrodev.com/archiva/repository/3rdparty/com/collabnet/subversion-edge/2.2.0-maestrodev/subversion-edge-2.2.0-maestrodev-linux-x86_64.tar.gz
  
  Exec { path => "/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin" }
  File { owner => $user, group => $group }

  
  if ! defined (Package[$jdk]) {
    package { $jdk: ensure => installed }
  }

  if ! defined (User[$user]) {
    user { $user:
      ensure     => present,
      home       => $home,
      managehome => false,
    } ->
    group { $group:
      ensure  => present,
    } ->
    exec { "sudo":
      command => "echo 'maestro         ALL=(ALL)               NOPASSWD: ALL' >> /etc/sudoers",
    }
  }

  if ! defined (File["/etc/profile.d/set_java_home.sh"]) {
    file { "/etc/profile.d/set_java_home.sh":
        ensure => present,
        source => "puppet:///modules/subversion_edge/set_java_home.sh",
        mode => 755
    } ->
    exec { "/bin/sh /etc/profile": 
    }
  }

  wget::authfetch { "download-subversion-edge":
    user => $repo['username'],
    password => $repo['password'],
    source => "${download_url}/subversion-edge-${version}-linux-x86_64.tar.gz",
    destination => "/usr/local/subversion-edge-${version}-linux-x64_64.tar.gz",
  } ->
  exec { "untar-subversion-edge":
    cwd => "/usr/local",
    command => "tar zxvf subversion-edge-${version}-linux-x64_64.tar.gz",
    creates => "/usr/local/csvn",
  } ->
  file { "/usr/local/csvn":
    owner => $user,
    group => $group,
    recurse => true
  } ->
  file { "/usr/local/csvn/bin":
    mode => 775,
    recurse => true
  } ->
  file { $home:
    ensure => directory,
    mode => 0700,
  } ->
  exec { "install-subversion-edge":
    logoutput => true,
    user => $user,
    cwd => "/usr/local/csvn",
    environment => "JAVA_HOME=/usr/lib/jvm/jre-1.6.0-openjdk",
    command => "sudo -E /usr/local/csvn/bin/csvn install",
    creates => "/etc/init.d/csvn",
    require => [Package[$jdk],File['/etc/profile.d/set_java_home.sh']]
  }
   exec { 'csvn-run-as-user':
    command => "sed -i 's/#RUN_AS_USER=$/RUN_AS_USER=${user}/' /usr/local/csvn/data/conf/csvn.conf",
    unless  => "grep 'RUN_AS_USER=${user}' /usr/local/csvn/data/conf/csvn.conf",
    before  => Service['csvn'],
    require => Exec["install-subversion-edge"],
  }
  
  exec { 'csvn-run-as-user-csvn-httpd':
    command => "sed -i 's/#RUN_AS_USER=$/RUN_AS_USER=${user}/' /usr/local/csvn/bin/csvn-httpd",
    unless  => "grep 'RUN_AS_USER=${user}' /usr/local/csvn/bin/csvn-httpd",
    before  => Service['csvn'],
    require => Exec["install-subversion-edge"],
  }
 
  service { "csvn":
    enable => true,
    ensure => running,
    hasrestart => true,
    hasstatus => true,
    require => Exec["install-subversion-edge"]
  } 
  
}
