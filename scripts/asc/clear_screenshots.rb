# Delete every screenshot in every screenshot set of the draft version (all locales).
require 'spaceship'
APPLE_ID = ENV.fetch('ASC_USER'); TUNES_TEAM = ENV.fetch('ASC_TUNES_TEAM_ID')
Spaceship::ConnectAPI.login(APPLE_ID, nil, use_portal: false, use_tunes: true, tunes_team_id: TUNES_TEAM)
app = Spaceship::ConnectAPI::App.find('com.meflabs.SOLA') or abort('app not found')
edit = app.get_edit_app_store_version or abort('no draft version')
edit.get_app_store_version_localizations.each do |loc|
  loc.get_app_screenshot_sets.each do |set|
    shots = set.app_screenshots
    shots.each { |s| s.delete! }
    puts "  #{loc.locale} #{set.screenshot_display_type}: deleted #{shots.size}"
  end
end
