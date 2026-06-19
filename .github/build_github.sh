set -e

scheme=${scheme:-BLEScope}
archive_path=${archive_path:-archive}
artifact_name=${artifact_name:-$scheme}

if [ ! -d "$archive_path.xcarchive" ]; then
  echo "Archive not found at $archive_path.xcarchive"
  exit 1
fi

# Prepare Payload
rm -rf Payload
cp -R "$archive_path.xcarchive/Products/Applications" Payload

# Package IPA (unsigned)
rm -f "$artifact_name.ipa"
zip -r "$artifact_name.ipa" "Payload" -x "._*" -x ".DS_Store" -x "__MACOSX"
