#!/bin/sh
# Read first char
dd if=/var/mobile/Documents/feeds.json bs=1 count=1 2>/dev/null > /var/mobile/Documents/first_char
# Write new file
cat /var/mobile/Documents/first_char /var/mobile/Documents/test_feed.json > /var/mobile/Documents/feeds.json.new
echo -n "," >> /var/mobile/Documents/feeds.json.new
# Append rest of original file
dd if=/var/mobile/Documents/feeds.json bs=1 skip=1 2>/dev/null >> /var/mobile/Documents/feeds.json.new
mv /var/mobile/Documents/feeds.json.new /var/mobile/Documents/feeds.json
echo "Done"