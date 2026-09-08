# Ensure a draft App Store version exists for VERSION (create it from the live one if
# needed, AFTER_APPROVAL release) and write What's New in the 6 locales.
# Usage: scripts/asc/run.sh scripts/asc/prepare_version.rb 1.1.2
require 'spaceship'
Spaceship::ConnectAPI.login(ENV.fetch('ASC_USER'), nil, use_portal: false, use_tunes: true, tunes_team_id: ENV.fetch('ASC_TUNES_TEAM_ID'))
VERSION = ARGV[0] or abort('usage: prepare_version.rb <version>')
WHATS_NEW = {
  'fr-FR' => "Mesure des campagnes améliorée et optimisations sous le capot. Bon soleil, et protège bien ta peau !",
  'en-US' => "Improved campaign measurement and under-the-hood optimizations. Enjoy the sun, and take care of your skin!",
  'es-ES' => "Medición de campañas mejorada y optimizaciones internas. ¡Disfruta del sol y cuida tu piel!",
  'it'    => "Misurazione delle campagne migliorata e ottimizzazioni interne. Buon sole e proteggi la pelle!",
  'pt-PT' => "Medição de campanhas melhorada e otimizações internas. Bom sol e protege a tua pele!",
  'pt-BR' => "Medição de campanhas aprimorada e otimizações internas. Aproveite o sol e cuide da sua pele!",
}
app = Spaceship::ConnectAPI::App.find('com.meflabs.SOLA') or abort('app not found')
edit = app.get_edit_app_store_version
if edit.nil?
  Spaceship::ConnectAPI.post_app_store_version(app_id: app.id, attributes: { platform: 'IOS', versionString: VERSION, releaseType: 'AFTER_APPROVAL' })
  puts "created draft #{VERSION}"
elsif edit.version_string != VERSION
  Spaceship::ConnectAPI.patch_app_store_version(app_store_version_id: edit.id, attributes: { versionString: VERSION })
  puts "renamed draft #{edit.version_string} -> #{VERSION}"
else
  puts "draft #{VERSION} exists (#{edit.app_store_state})"
end
edit = app.get_edit_app_store_version
locs = edit.get_app_store_version_localizations
WHATS_NEW.each do |locale, text|
  loc = locs.find { |l| l.locale == locale } or (puts "MISSING locale #{locale}"; next)
  Spaceship::ConnectAPI.patch_app_store_version_localization(app_store_version_localization_id: loc.id, attributes: { whatsNew: text })
  puts "whatsNew #{locale} ok"
end
# read back
edit.get_app_store_version_localizations.each { |l| puts "  #{l.locale}: #{l.whats_new&.slice(0, 60)}" }
