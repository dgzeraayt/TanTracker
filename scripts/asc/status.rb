# Print the current App Store state of the edit/live versions.
require 'spaceship'
Spaceship::ConnectAPI.login(ENV.fetch('ASC_USER'), nil, use_portal: false, use_tunes: true, tunes_team_id: ENV.fetch('ASC_TUNES_TEAM_ID'))
app = Spaceship::ConnectAPI::App.find('com.meflabs.SOLA') or abort('app not found')
live = app.get_live_app_store_version
puts "LIVE #{live&.version_string} #{live&.app_store_state}"
edit = app.get_edit_app_store_version || app.get_pending_release_app_store_version || app.get_in_review_app_store_version
puts "NEXT #{edit&.version_string} #{edit&.app_store_state} build=#{edit&.build&.version} release=#{edit&.release_type}" if edit
