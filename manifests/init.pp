#
# @param webhook Slack Webhook API URL
# @param channel Slack Channel name
# @param puppetconsole PE Console hostname
# @param icon_url What URL to use for the icon in the Slack message
#
# Authors
# -------
#
# Daniel Wittenberg <dan.wittenberg@thinkahead.com>
#

class report2slack (
  String $webhook,
  String $channel,
  String $puppetconsole = $settings::ca_server,
  String $icon_url = 'https://learn.puppet.com/static/images/logos/Puppet-Logo-Mark-Amber.png',
) {
  validate_re($webhook, 'https:\/\/hooks.slack.com\/(services\/)?T.+\/B.+\/.+', 'The webhook URL is invalid')
  validate_re($channel, '#.+', 'The channel should start with a hash sign')
  validate_re($puppetconsole, '.+')
  validate_re($icon_url, '.+')

  pe_ini_setting { "${module_name}_enable_reports":
    ensure  => present,
    path    => "${settings::confdir}/puppet.conf",
    section => 'agent',
    setting => 'report',
    value   => true,
  }

  pe_ini_subsetting { "${module_name}_report_handler" :
    ensure               => present,
    path                 => "${settings::confdir}/puppet.conf",
    section              => 'master',
    setting              => 'reports',
    subsetting           => $module_name,
    subsetting_separator => ',',
    notify               => Service['pe-puppetserver'],
  }

  file { "${settings::confdir}/${module_name}.yaml":
    ensure  => present,
    owner   => 'pe-puppet',
    group   => 'pe-puppet',
    mode    => '0644',
    content => epp("${module_name}/${module_name}.yaml.epp"),
  }
}
