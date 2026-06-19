set -e

artifact_name=${artifact_name:-BLEScope-maccatalyst}
volume_name=${volume_name:-BLEScope}

if [ -z "$app_path" ] || [ ! -d "$app_path" ]; then
  echo "Mac app not found at app_path=$app_path"
  exit 1
fi

staging_dir=$(mktemp -d)
trap 'rm -rf "$staging_dir"' EXIT

cp -R "$app_path" "$staging_dir/"
ln -s /Applications "$staging_dir/Applications"

rm -f "$artifact_name.dmg"
hdiutil create \
  -volname "$volume_name" \
  -srcfolder "$staging_dir" \
  -ov \
  -format UDZO \
  "$artifact_name.dmg"
