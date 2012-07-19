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

require File.dirname(__FILE__) + "/formatter"

class ConsoleFormatter < Formatter

  def initialize(options = {})
    super(options.merge(:show_progress_bar => true, :has_user_interaction => true))
  end

  def empty_line
    "\n"
  end

  def updater_update(update_results)
    update_results
  end

  def updater_not_available
    "Svn / Git not installed, or wpscan has not been installed with one of them."
  end

  def update_aborted
    "Update aborted"
  end

  def following_redirection(redirection)
    "Following redirection #{redirection}\n" +
    empty_line()
  end

  def redirection_detected(redirection)
    "The remote host tried to redirect us to #{redirection}"
  end

  def question(question)
    question
  end

  def scan_aborted
    "Scan aborted"
  end

  def start_message(target_url, time)
    "| URL: #{target_url}\n" +
    "| Started on #{time.asctime}\n" +
    empty_line()
  end

  def theme(name, version)
    "[!] The WordPress theme in use is #{name}#{' v' + version if version}"
  end

  def number_of_theme_vulnerabilities(number)
    "[+] We have identified #{number} vulnerabilities for this theme :"
  end

  def theme_vulnerability(vulnerability)
    empty_line() +
    " | * Title: #{vulnerability.title}\n" +
    " | * Reference: #{vulnerability.reference}"
  end

  def theme_vulnerabilities_separator
    empty_line()
  end

  def readme_url(url)
    "[!] The WordPress '#{url}' file exists"
  end

  def full_path_disclosure_url(url)
    "[!] Full Path Disclosure (FPD) in '#{url}'"
  end

  def config_file_url(url)
    "[!] A wp-config.php backup file has been found '#{url}'"
  end

  def number_of_malwares_found(number)
    "[!] #{number} malware(s) found :"
  end

  def malware_url(url)
    " | #{url}"
  end

  def malwares_separator
    empty_line()
  end

  def version(number, discovery_method)
    "[!] WordPress version #{number} identified from #{discovery_method}"
  end

  def number_of_version_vulnerabilities(number)
    empty_line() +
    "[+] We have identified #{number} vulnerabilities from the version number :"
  end

  def version_vulnerability(vulnerability)
    # Same format than the theme
    theme_vulnerability(vulnerability)
  end

  def version_vulnerabilities_separator
    empty_line()
  end

end
