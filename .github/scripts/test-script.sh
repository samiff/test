#!/bin/bash
# This script is ran as part of the `UpdateJetpackStaging` TeamCity build.
# It updates pre-defined Atomic sites with the latest plugin versions.

####################################################
## Script variables.
####################################################

TMP_DIR=$(mktemp -d) # Temp dir where the plugin .zip files are downloaded and unpacked.
REMOTE_DIR='/srv/htdocs/jetpack-staging' # Remote dir where the unpacked Jetpack files are synced to.
PLUGINS=( "jetpack" "jetpack-mu-wpcom-plugin" ); # Plugins to update.
declare -A PLUGIN_VERSIONS # Array used to hold fetched plugin versions.
declare -A PLUGIN_DOWNLOAD_URLS # Array used to hold fetched plugin download URLs.

# Atomic test sites where the typical root symlink for Jetpack has been removed, enabling writing of new versions.
# On these sites, '/srv/htdocs/wp-content/plugins/jetpack' symlink points to '/srv/htdocs/jetpack-staging',
# and 'plugins/jetpack-platform' is the Atomic platform copy of the plugin.
#
# WPcom account 'jetpackisbestpack': https://mc.a8c.com/secret-store/?secret_id=10538
# SSH uses the 'TC_UPDATEJETPACKSTAGING_SSH_KEY' secret, added as an env var to TeamCity,
# see: https://wordpress.com/support/connect-to-ssh-on-wordpress-com/#ssh-key
SITES='{
  "jetpackedge.wpcomstaging.com": {
    "url": "https://jetpackedge.wpcomstaging.com/",
    "note": "normal site",
    "ssh_string": "jetpackedge.wordpress.com@sftp.wp.com",
    "blog_id": "215379549"
  },
  "jetpackedgephp74.wpcomstaging.com": {
    "url": "https://jetpackedgephp74.wpcomstaging.com/",
    "note": "php 7.4",
    "ssh_string": "jetpackedgephp74.wordpress.com@sftp.wp.com",
    "blog_id": "215379848"
  }
}'
# Todo: add the other sites to $SITES

####################################################
## Fetch plugin data from the Jetpack Beta Builder.
####################################################

# Fetch the latest data from the Jetpack Beta Builder for each plugin.
for PLUGIN in "${PLUGINS[@]}"; do
  echo "Fetching latest $PLUGIN data from the Jetpack Beta Builder..."
  if ! RESPONSE=$(curl -s https://betadownload.jetpack.me/$PLUGIN-branches.json); then
    echo "Error: unable to fetch data from Jetpack Beta Builder for $PLUGIN."
    exit 1
  fi

  DOWNLOAD_URL=$(echo "$RESPONSE" | jq -r ".master.download_url")
  PLUGIN_VERSION=$(echo "$RESPONSE" | jq -r ".master.version")

  if [[ -z "$DOWNLOAD_URL" || -z "$PLUGIN_VERSION" ]]; then
    echo "Error: unable to extract data from Jetpack Beta Builder response for $PLUGIN."
    exit 1
  else
    echo "Returned version number for $PLUGIN: $PLUGIN_VERSION"
    PLUGIN_VERSIONS[$PLUGIN]="$PLUGIN_VERSION"
    PLUGIN_DOWNLOAD_URLS[$PLUGIN]="$DOWNLOAD_URL"
  fi
done

####################################################
## Download and unpack the plugin .zip files.
####################################################

for PLUGIN in "${PLUGINS[@]}"; do
  echo "Attempting to download $PLUGIN .zip file..."
  if ! curl -f -o "$TMP_DIR/$PLUGIN-dev.zip" "${PLUGIN_DOWNLOAD_URLS[$PLUGIN]}"; then
    echo "Download of $PLUGIN .zip failed, exiting."
    exit 1
  else
    echo "Download of $PLUGIN .zip completed."
  fi

  echo "Unpacking .zip file to: $TMP_DIR/$PLUGIN"
  if ! unzip -q "$TMP_DIR/$PLUGIN-dev.zip" -d "$TMP_DIR"; then
    echo "Unpacking of the .zip failed, exiting."
    exit 1
  else
    echo "Unpacking of $PLUGIN completed successfully."
    # Add a version.txt file for easy curl retrieval on the MC release button page.
    echo "${PLUGIN_VERSIONS[$PLUGIN]}" > "$TMP_DIR/$PLUGIN-dev/version.txt"
  fi
done

####################################################
## Sync the new Jetpack files.
####################################################

# Write the SSH key to temp file for use in the rsync command.
echo "$TC_UPDATEJETPACKSTAGING_SSH_KEY" > "$TMP_DIR/ssh_key"
chmod 0600 "$TMP_DIR/ssh_key"

# Sync new plugin files to the Atomic test sites.
EXIT_CODE=0
for key in $(echo "${SITES}" | jq -r 'keys[]'); do
  # Extract values for each site.
  ssh_string=$(echo "${SITES}" | jq -r --arg key "$key" '.[$key].ssh_string')
  blog_id=$(echo "${SITES}" | jq -r --arg key "$key" '.[$key].blog_id')

  # Attempt to rsync each plugin directory files over SSH.
  for PLUGIN in "${PLUGINS[@]}"; do
    echo "Attempting to sync $PLUGIN files to $key | blog_id: $blog_id"
    if ! rsync -az --quiet --delete -e "ssh -i $TMP_DIR/ssh_key" "$TMP_DIR/$PLUGIN-dev/" "$ssh_string:$REMOTE_DIR/$PLUGIN/"; then
      echo "Failed to sync $PLUGIN files to $key | blog_id: $blog_id"
      EXIT_CODE=1
    else
      echo "Successfully synced $PLUGIN files to $key | blog_id: $blog_id"
    fi
  done
done

####################################################
## Cleanup.
####################################################

echo 'Cleaning up...'
rm -rf "$TMP_DIR"
echo "$(basename $0) script finished."
exit $EXIT_CODE
