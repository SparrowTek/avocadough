#!/bin/zsh

#  ci_post_clone.sh
#  Avocadough
#
#  Created by Thomas Rademaker on 1/9/24.
#  

development_team_value=$DEVELOPMENT_TEAM
bundle_id_prefix_value=$BUNDLE_ID_PREFIX

config_file_path="../User.xcconfig"

# Trust SwiftPM build tool plugins (e.g. swift-secp256k1's SharedSourcesPlugin)
# so Xcode Cloud doesn't fail with "Plugin must be enabled before it can be used".
defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation -bool YES
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES

# Check for the presence of 'user.xcconfig'
if [ -f "$config_file_path" ]; then
echo "User.xcconfig exists."
else
echo "Creating User.xcconfig and populating it with environment variables"
echo "DEVELOPMENT_TEAM = $development_team_value" > "$config_file_path"
echo "BUNDLE_ID_PREFIX = $bundle_id_prefix_value" >> "$config_file_path"
fi
