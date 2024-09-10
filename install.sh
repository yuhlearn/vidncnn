#! /bin/bash

warning () {
	echo "Warning: $1"
}

error () {
	echo "Error: $1"
	echo "Installation failed."
	exit 1
}

# Gets the latest zip release from github
get_latest_release () {
	local URL=
	URL=$(curl -s "$1" | grep browser_download_url | grep "ubuntu" | head -1 | cut -d '"' -f 4)
	if [ ! "$URL" ]; then
		warning "Failed to get latest release from '$1'"
	else
		wget -q --show-progress --progress=bar:force "$URL"
	fi
}

INSTALL_PATH="/usr/local"

# Install some dependencies
if ! apt install curl ffmpeg imagemagick rsync unzip util-linux wget -y; then
	warning "apt does not seem to be available on this system, make sure dependancies are met"
fi

get_latest_release "https://api.github.com/repos/xinntao/Real-ESRGAN/releases"
get_latest_release "https://api.github.com/repos/nihui/rife-ncnn-vulkan/releases"

# Extract the contents of the archives
for ARCHIVE in *ubuntu.zip; do
	TOPLEVEL="$(unzip -l "$ARCHIVE" | head -4 | tail -1 | tr -s " " | cut -d " " -f 5 | grep "/")"
	DIRECTORY="${ARCHIVE%.*}"
	[[ $DIRECTORY =~ ([a-zA-Z.-_%+-]+)-([0-9]+-ubuntu) ]]
	EXECUTABLE="${BASH_REMATCH[1]}"
	echo
	echo "Extracting '$ARCHIVE'"
	if
		if [[ -z "$TOPLEVEL" ]]; then
			unzip -qod "$DIRECTORY" "$ARCHIVE"
		else
			unzip -qo "$ARCHIVE"
		fi
	then
		chmod +x "$DIRECTORY/$EXECUTABLE"	
		rm -v "$ARCHIVE"
	else
		warning "Failed to extract '$ARCHIVE'"
		continue
	fi
	
	if rsync -a "$DIRECTORY" "$INSTALL_PATH" && \
		ln -vfs "$INSTALL_PATH/$DIRECTORY/$EXECUTABLE" "$INSTALL_PATH/bin/$EXECUTABLE"
	then
		rm -rf "$DIRECTORY"
		echo "Successfully installed '$EXECUTABLE' to '$INSTALL_PATH'"
	else
		warning "Failed to install '$EXECUTABLE' to '$INSTALL_PATH'"
	fi
done

echo
if rsync -a "videnh" "$INSTALL_PATH/bin/videnh"
then
	echo "Successfully installed 'videnh' to '$INSTALL_PATH'"
else
	warning "Failed to install 'videnh' to '$INSTALL_PATH'"
fi

