set -e

scheme=${scheme:-BLEScope}
archive_path=${archive_path:-archive}

if [ ! -d "$archive_path.xcarchive" ]; then
  echo "Archive not found at $archive_path.xcarchive"
  exit 1
fi

# Prepare Payload
rm -rf Payload
mv "$archive_path.xcarchive/Products/Applications" Payload

# Package IPA (unsigned)
rm -f "$scheme.ipa"
zip -r "$scheme.ipa" "Payload" -x "._*" -x ".DS_Store" -x "__MACOSX"
