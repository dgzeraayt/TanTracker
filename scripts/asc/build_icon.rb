# Download the App Store icon that ASC extracted from a given build.
# Usage: scripts/asc/run.sh scripts/asc/build_icon.rb 19 /tmp/icon.png
require 'spaceship'; require 'open-uri'
Spaceship::ConnectAPI.login(ENV.fetch('ASC_USER'), nil, use_portal: false, use_tunes: true, tunes_team_id: ENV.fetch('ASC_TUNES_TEAM_ID'))
app = Spaceship::ConnectAPI::App.find('com.meflabs.SOLA') or abort('app not found')
build = Spaceship::ConnectAPI::Build.all(app_id: app.id, sort: '-uploadedDate', limit: 5).find { |b| b.version == ARGV[0] } or abort('build not found')
tok = build.icon_asset_token or abort('no icon asset token yet')
url = tok['templateUrl'].sub('{w}', '1024').sub('{h}', '1024').sub('{f}', 'png')
File.binwrite(ARGV[1], URI.open(url).read)
puts "saved #{ARGV[1]} from build #{build.version} (#{build.processing_state})"
