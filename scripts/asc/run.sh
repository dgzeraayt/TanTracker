#!/usr/bin/env bash
# Run a spaceship/deliver ruby script with fastlane's own ruby + gem env.
# Usage: scripts/asc/run.sh scripts/asc/upload_screenshots.rb
set -euo pipefail
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
export GEM_HOME="$HOME/.local/share/fastlane/4.0.0"
export GEM_PATH="$HOME/.local/share/fastlane/4.0.0:/opt/homebrew/Cellar/fastlane/2.234.0/libexec"
export RUBYOPT="-EUTF-8" LC_ALL="en_US.UTF-8" FASTLANE_SKIP_UPDATE_CHECK=1
export ASC_USER="${ASC_USER:-berkaytrk6@gmail.com}"
export ASC_TUNES_TEAM_ID="${ASC_TUNES_TEAM_ID:-128389402}"   # GH SERVICOS DIGITAIS LTDA
exec /opt/homebrew/opt/ruby/bin/ruby "$@" < /dev/null
