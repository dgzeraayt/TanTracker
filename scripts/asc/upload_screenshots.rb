# Upload App Store screenshots for all locales to the edit (draft) version.
# Auth: existing spaceship cookie for the Apple ID (no password / 2FA prompt).
# Run with fastlane's ruby env — see scripts/asc/run.sh
require 'deliver'
require 'spaceship'

APPLE_ID = ENV.fetch('ASC_USER')
TUNES_TEAM = ENV.fetch('ASC_TUNES_TEAM_ID')
BUNDLE = 'com.meflabs.SOLA'
SHOTS = File.expand_path('../../Design/Goldn2026/appstore', __dir__)

Spaceship::ConnectAPI.login(APPLE_ID, nil, use_portal: false, use_tunes: true, tunes_team_id: TUNES_TEAM)
app = Spaceship::ConnectAPI::App.find(BUNDLE) or abort("app not found")

opts = FastlaneCore::Configuration.create(Deliver::Options.available_options, {
  app_identifier: BUNDLE, platform: 'ios',
  screenshots_path: SHOTS, overwrite_screenshots: true,
  skip_metadata: true, skip_binary_upload: true, force: true
})
Deliver.cache[:app] = app
uploader = Deliver::UploadScreenshots.new
shots = uploader.collect_screenshots(opts)
puts "collected #{shots.size}: " + shots.group_by(&:language).map { |l, s| "#{l}=#{s.size}" }.join(' ')
uploader.upload(opts, shots)

edit = app.get_edit_app_store_version
edit.get_app_store_version_localizations.each do |loc|
  sets = loc.get_app_screenshot_sets
  puts "  #{loc.locale}: " + sets.map { |s| "#{s.screenshot_display_type}=#{s.app_screenshots.size}" }.join(', ')
end
