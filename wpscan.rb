#!/usr/bin/env ruby

#
# WPScan - WordPress Security Scanner
# Copyright (C) 2011  Ryan Dewhurst AKA ethicalhack3r
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# ryandewhurst at gmail
#

$: << '.'
require File.dirname(__FILE__) +'/lib/wpscan/wpscan_helper'

banner()

begin
  wpscan_options = WpscanOptions.load_from_arguments
  formatter      = ConsoleFormatter.new

  unless wpscan_options.has_options?
    raise "No argument supplied\n#{usage()}"
  end

  if wpscan_options.help
    help()
    exit
  end

  # Check for updates
  if wpscan_options.update
    unless @updater.nil?
      puts formatter.updater_update(@updater.update())
    else
      puts formatter.updater_not_available
      puts formatter.update_aborted
    end
    exit(1)
  end

  wp_target = WpTarget.new(wpscan_options.url, wpscan_options.to_h)

  # Remote website up?
  unless wp_target.is_online?
    raise "The WordPress URL supplied '#{wp_target.uri}' seems to be down."
  end

  if redirection = wp_target.redirection
    if wpscan_options.follow_redirection
      puts formatter.following_redirection(redirection)
    else
      puts formatter.redirection_detected(redirection)
      puts formatter.question("Do you want follow the redirection ? [y/n]") if formatter.has_user_interaction?
    end

    if wpscan_options.follow_redirection or (formatter.has_user_interaction? and Readline.readline =~ /^y/i)
      wpscan_options.url = redirection
      wp_target = WpTarget.new(redirection, wpscan_options.to_h)
    else
      puts formatter.scan_aborted
      exit
    end
  end

  # Remote website is wordpress?
  unless wpscan_options.force
    unless wp_target.is_wordpress?
      raise "The remote website is up, but does not seem to be running WordPress."
    end
  end

  if wp_content_dir = wp_target.wp_content_dir()
    Browser.instance.variables_to_replace_in_url = {"$wp-content$" => wp_content_dir, "$wp-plugins$" => wp_target.wp_plugins_dir()}
  else
    raise "The wp_content_dir has not been found, please supply it with --wp-content-dir"
  end

  # Output runtime data
  puts formatter.start_message(wp_target.url, Time.now)

  # Can we identify the theme name?
  if wp_theme = wp_target.theme
    puts formatter.theme(wp_theme.name, wp_theme.version)

    theme_vulnerabilities = wp_theme.vulnerabilities
    unless theme_vulnerabilities.empty?
      puts formatter.number_of_theme_vulnerabilities(theme_vulnerabilities.size)

      theme_vulnerabilities.each do |vulnerability|
        puts formatter.theme_vulnerability(vulnerability)
      end
      puts formatter.theme_vulnerabilities_separator if formatter.theme_vulnerabilities_separator
    end
  end

  # Is the readme.html file there?
  if wp_target.has_readme?
    puts formatter.readme_url(wp_target.readme_url)
  end

  # Full Path Disclosure (FPD)?
  if wp_target.has_full_path_disclosure?
    puts formatter.full_path_disclosure_url(wp_target.full_path_disclosure_url)
  end

  # Is the wp-config.php file backed up?
  wp_target.config_backup.each do |file_url|
    puts formatter.config_file_url(file_url)
  end

  # Checking for malwares
  if wp_target.has_malwares?
    malwares = wp_target.malwares
    puts formatter.number_of_malwares_found(malwares.size)

    malwares.each do |malware_url|
      puts formatter.malware_url(malware_url)
    end
    puts formatter.malwares_separator if formatter.malwares_separator
  end

  # Checking the version...
  if wp_version = wp_target.version
    puts formatter.version(wp_version.number, wp_version.discovery_method)

    # Are there any vulnerabilities associated with this version?
    version_vulnerabilities = wp_version.vulnerabilities

    unless version_vulnerabilities.empty?
      puts formatter.number_of_version_vulnerabilities(version_vulnerabilities.size)

      version_vulnerabilities.each do |vulnerability|
        puts formatter.version_vulnerability(vulnerability)
      end
      puts formatter.version_vulnerabilities_separator if formatter.version_vulnerabilities_separator
    end
  end

  # Plugins from passive detection
  #puts
  print "[+] Enumerating plugins from passive detection ... "

  plugins = wp_target.plugins_from_passive_detection
  unless plugins.empty?
    print "#{plugins.size} found :\n"

    plugins.each do |plugin|
      puts
      puts " | Name: " + plugin.name
      puts " | Location: " + plugin.location_url

      plugin.vulnerabilities.each do |vulnerability|
        puts " |"
        puts " | [!] " + vulnerability.title
        puts " | * Reference: " + vulnerability.reference
      end
    end
  else
    print "No plugins found :(\n"
  end

  # Enumerate the installed plugins
  if wpscan_options.enumerate_plugins or wpscan_options.enumerate_only_vulnerable_plugins
    puts
    puts "[+] Enumerating installed plugins #{'(only vulnerable ones)' if wpscan_options.enumerate_only_vulnerable_plugins} ..."
    puts

    plugins = wp_target.plugins_from_aggressive_detection(
      :only_vulnerable_ones => wpscan_options.enumerate_only_vulnerable_plugins,
      :show_progress_bar => true
    )
    unless plugins.empty?
      puts
      puts
      puts "[+] We found " + plugins.size.to_s  + " plugins:"

      plugins.each do |plugin|
        puts
        puts " | Name: " + plugin.name
        puts " | Location: " + plugin.location_url

        puts " | Directory listing enabled? #{plugin.directory_listing? ? "Yes." : "No."}"

        plugin.vulnerabilities.each do |vulnerability|
          #vulnerability['vulnerability'][0]['uri'] == nil ? "" : uri = vulnerability['vulnerability'][0]['uri'] # uri
          #vulnerability['vulnerability'][0]['postdata'] == nil ? "" : postdata = CGI.unescapeHTML(vulnerability['vulnerability'][0]['postdata']) # postdata

          puts " |"
          puts " | [!] " + vulnerability.title
          puts " | * Reference: " + vulnerability.reference

          # This has been commented out as MSF are moving from
          # XML-RPC to MessagePack.
          # I need to get to grips with the new way of communicating
          # with MSF and implement new code.

          # check if vuln is exploitable
          #Exploit.new(url, type, uri, postdata.to_s, use_proxy, proxy_addr, proxy_port)
        end

        if plugin.error_log?
          puts " | [!] A WordPress error_log file has been found : " + plugin.error_log_url
        end
      end
    else
      puts
      puts "No plugins found :("
    end
  end

  # try to find timthumb files
  if wpscan_options.enumerate_timthumbs
    puts
    puts "[+] Enumerating timthumb files ..."
    puts

    if wp_target.has_timthumbs?(:theme_name => wp_theme ? wp_theme.name : nil, :show_progress_bar => true)
      timthumbs = wp_target.timthumbs

      puts
      puts "[+] We found " + timthumbs.size.to_s  + " timthumb file/s :"
      puts

      timthumbs.each do |file_url|
        puts " | [!] " +  file_url
      end
      puts
      puts " * Reference: http://www.exploit-db.com/exploits/17602/"
    else
      puts
      puts "No timthumb files found :("
    end
  end

  # If we haven't been supplied a username, enumerate them...
  if !wpscan_options.username and wpscan_options.wordlist or wpscan_options.enumerate_usernames
    puts
    puts "[+] Enumerating usernames ..."

    usernames = wp_target.usernames(:range => wpscan_options.enumerate_usernames_range)

    if usernames.empty?
      puts
      puts "We did not enumerate any usernames :("
      puts "Try supplying your own username with the --username option"
      puts
      exit(1)
    else
      puts
      puts "We found the following " + usernames.length.to_s + " username/s :"
      puts

      usernames.each {|username| puts "  " + username}
    end

  else
    usernames = [wpscan_options.username]
  end

  # Start the brute forcer
  if wpscan_options.wordlist
    if wp_target.has_login_protection?

      protection_plugin = wp_target.login_protection_plugin()

      puts
      puts "The plugin #{protection_plugin.name} has been detected. It might record the IP and timestamp of every failed login. Not a good idea for brute forcing !"
      puts "[?] Do you want to start the brute force anyway ? [y/n]"

      if Readline.readline !~ /^y/i
        bruteforce = false
      end
    end

    if bruteforce === false
      puts
      puts "Brute forcing aborted"
    else
      puts
      puts "[+] Starting the password brute forcer"
      puts
      wp_target.brute_force(usernames, wpscan_options.wordlist)
    end
  end

  puts
  puts '[+] Finished at ' + Time.now.asctime
  exit() # must exit!
rescue => e
  puts "[ERROR] #{e}"
  puts "Trace : #{e.backtrace}"
end
