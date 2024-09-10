#! /bin/bash

INSTALL_PATH="/usr/local"

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
	local URL
	local ARCHIVE
	local DIRECTORY
	local EXECUTABLE
	
	URL=$(curl -s "$1" | grep browser_download_url | grep "ubuntu" | head -1 | cut -d '"' -f 4)
	ARCHIVE="$(basename $URL)"
	DIRECTORY="${ARCHIVE%.*}"
		[[ $DIRECTORY =~ ([a-zA-Z.-_%+-]+)-([0-9]+-ubuntu) ]]
	EXECUTABLE="${BASH_REMATCH[1]}"
	
	echo
		
	# Check if we got the URL
	if [ ! "$URL" ]; then
		# This is usually and API error -- try later or DIY
		warning "Failed to find latest release in '$1'. Try again later or try a manual install."
		return 1
	else
		# Check if the latest version is already installed
		if [ -d "$INSTALL_PATH/$DIRECTORY" ]; then
			echo "The latest release '$DIRECTORY' is already exists in '$INSTALL_PATH'. Cancelling download."
			return 0
		fi
	
		# Check if we already downloaded the archive
		if [ ! -f "$ARCHIVE" ]; then
			# Try downloading the archive
			if ! wget -q --show-progress --progress=bar:force "$URL"
			then
				warning "Failed to download latest release from '$URL'"
				return 2
			fi
		fi
	fi
	
	echo "Extracting '$ARCHIVE'"
	if ! unzip -qod "$DIRECTORY" "$ARCHIVE"
	then
		warning "Failed to unzip the archive '$ARCHIVE'"
		return 3
	else
		if [ -d "$DIRECTORY/$DIRECTORY" ]; then
			if ! rsync -a ./"$DIRECTORY/$DIRECTORY" ./
			then
				warning "Failed to create the correct folder structure for '$DIRECTORY'"
				return 4
			fi
		fi
		chmod +x "$DIRECTORY/$EXECUTABLE"	
		rm -v "$ARCHIVE"
	fi
	
	if rsync -a "$DIRECTORY" "$INSTALL_PATH" && \
		ln -vfs "$INSTALL_PATH/$DIRECTORY/$EXECUTABLE" "$INSTALL_PATH/bin/$EXECUTABLE"
	then
		rm -rf "$DIRECTORY"
		echo "Successfully installed '$EXECUTABLE' to '$INSTALL_PATH'"
	else
		warning "Failed to install '$EXECUTABLE' to '$INSTALL_PATH'"
		return 5
	fi
}

if [[ $EUID > 0 ]]; then  
	error "Please run with sudo: 'sudo ./install'"
fi

# Install some dependencies
if ! apt install curl ffmpeg imagemagick rsync unzip util-linux wget -y; then
	warning "apt does not seem to be available on this system, make sure dependancies are met"
fi

get_latest_release "https://api.github.com/repos/xinntao/Real-ESRGAN/releases"
get_latest_release "https://api.github.com/repos/nihui/rife-ncnn-vulkan/releases"

echo
if rsync -a "videnh" "$INSTALL_PATH/bin/videnh"
then
	echo "Successfully installed 'videnh' to '$INSTALL_PATH'"
else
	warning "Failed to install 'videnh' to '$INSTALL_PATH'"
fi

