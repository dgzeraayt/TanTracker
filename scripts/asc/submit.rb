# Attach the processed build to the draft version and submit for review.
# Usage: scripts/asc/run.sh scripts/asc/submit.rb 1.1.1 19
require 'spaceship'

APPLE_ID = ENV.fetch('ASC_USER')
TUNES_TEAM = ENV.fetch('ASC_TUNES_TEAM_ID')
BUNDLE = 'com.meflabs.SOLA'
VERSION = ARGV[0] or abort("usage: submit.rb <version> <build>")
BUILD = ARGV[1] or abort("usage: submit.rb <version> <build>")

Spaceship::ConnectAPI.login(APPLE_ID, nil, use_portal: false, use_tunes: true, tunes_team_id: TUNES_TEAM)
app = Spaceship::ConnectAPI::App.find(BUNDLE) or abort("app not found")
version = app.get_edit_app_store_version
abort("no draft version") unless version && version.version_string == VERSION

build = nil
12.times do
  build = Spaceship::ConnectAPI::Build.all(app_id: app.id, sort: '-uploadedDate', limit: 5)
                                     .find { |b| b.version == BUILD && b.pre_release_version&.version == VERSION }
  break if build && build.processing_state == 'VALID'
  puts "waiting for build #{VERSION} (#{BUILD})… state=#{build&.processing_state || 'not yet uploaded'}"
  sleep 60
end
abort("build #{VERSION} (#{BUILD}) not processed") unless build && build.processing_state == 'VALID'

# Encryption compliance: App-Info.plist has ITSAppUsesNonExemptEncryption, but set it explicitly too.
begin
  Spaceship::ConnectAPI.patch_build(build_id: build.id, attributes: { usesNonExemptEncryption: false })
rescue => e
  puts "encryption flag: #{e.message[0, 80]}"
end

version.select_build(build_id: build.id)
puts "attached build #{build.version} to #{version.version_string}"

sub = app.create_review_submission(platform: Spaceship::ConnectAPI::Platform::IOS)
sub.add_app_store_version_to_review_items(app_store_version_id: version.id)
sub.submit_for_review
puts "SUBMITTED #{VERSION} (#{BUILD}) for review — release type #{version.release_type}"
