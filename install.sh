#! /bin/bash

INSTALL_PATH="/usr/local"
GIT_REPOS=("https://api.github.com/repos/xinntao/Real-ESRGAN/releases" \
		   "https://api.github.com/repos/nihui/rife-ncnn-vulkan/releases")
UPSCAYL_MODELS="https://github.com/upscayl/custom-models/archive/refs/heads/main.zip"
WARNINGS=0

function prompt() {
	printf "\n$1\n"
    read -p "Do you wish to continue with this step? ([y]es/[N]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) return 0 ;;
        *)     echo "Skipped."; return 1 ;;
    esac
}
export -f prompt

warning () {
	((WARNINGS++))
	echo "Warning [$WARNINGS]: $1"
}

error () {
	echo "Error: $1"
	echo "Installation failed."
	exit 1
}

# Downloads and installs the latest zip release from github
get_latest_release () {
	local URL
	local ARCHIVE
	local DIRECTORY
	local EXECUTABLE
	
	# Fetch the URL to the latest zip release for Ubuntu.
	URL=$(curl -s "$1" | grep browser_download_url | grep "ubuntu" | head -1 | cut -d '"' -f 4)
	ARCHIVE="$(basename $URL)"
	DIRECTORY="${ARCHIVE%.*}"
		[[ $DIRECTORY =~ ([a-zA-Z.-_%+-]+)-([0-9]+-ubuntu) ]]
	EXECUTABLE="${BASH_REMATCH[1]}"
			
	# Check if we got the URL
	if [ ! "$URL" ]; then
		# This is usually and API error -- try later or DIY
		warning "Failed to find latest release in '$1'. Try again later or try a manual install."
		return 1
	else
		# Check if the latest version is already installed
		if [ -d "$INSTALL_PATH/$DIRECTORY" ]; then
			warning "The latest release '$DIRECTORY' already exists in '$INSTALL_PATH'. Cancelling download."
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
	
	# Try to unzip the archive
	echo "Extracting '$ARCHIVE'"
	if ! unzip -qod "$DIRECTORY" "$ARCHIVE"
	then
		warning "Failed to unzip the archive '$ARCHIVE'"
		return 3
	else
		# Check if we need to move files down a notch
		if [ -d "$DIRECTORY/$DIRECTORY" ]; then
			if ! rsync -a ./"$DIRECTORY/$DIRECTORY" ./
			then
				warning "Failed to create the correct folder structure for '$DIRECTORY'"
				return 4
			fi
		fi
		# Clean up
		chmod +x "$DIRECTORY/$EXECUTABLE"	
		rm -v "$ARCHIVE"
	fi
	
	# Try to install the files to $INSTALL_PATH
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

get_latest_ergan_models() {
	local ESRGAN_VERSION
	local ARCHIVE
	local DIRECTORY
	ESRGAN_VERSION="$1"
	DIRECTORY="custom-models-main"
	ARCHIVE="$DIRECTORY.zip"
	
	# Check if we already downloaded the archive
	if [ ! -f "$ARCHIVE" ]; then
		# Try downloading the archive
		if ! wget -q --show-progress --progress=bar:force "$UPSCAYL_MODELS" -O "$ARCHIVE"
		then
			warning "Failed to download latest models from '$UPSCAYL_MODELS'"
			return 1
		fi
	fi
	
	# Try to unzip the archive
	echo "Extracting '$ARCHIVE'"
	if ! unzip -qo "$ARCHIVE"
	then
		warning "Failed to unzip the archive '$ARCHIVE'"
		return 2
	else
		rm -v "$ARCHIVE"
	fi
	
	# Try to install the files to $INSTALL_PATH
	if rsync -a "$DIRECTORY/models" "$ESRGAN_VERSION"
	then
		rm -rf "$DIRECTORY"
		echo "Successfully installed models to '$ESRGAN_VERSION/models'"
	else
		warning "Failed to install models to '$ESRGAN_VERSION/models'"
		return 5
	fi
}

if [[ $EUID > 0 ]]; then  
	error "Please run with sudo: 'sudo ./install'"
fi

# Install some dependencies
if ! apt install curl ffmpeg imagemagick rsync unzip util-linux wget; then
	warning "apt does not seem to be available on this system, make sure dependancies are met"
fi

# Download and install from github repos
for REPO in ${GIT_REPOS[@]}; do
	if prompt "The script will attempt to download the latest release from '$REPO' and install it to '$INSTALL_PATH'."
	then
		get_latest_release "$REPO"
	fi
done

# Download and install additional esrgan models for the latest version installed in $INSTALL_PATH
LATEST_ESRGAN=$(find "$INSTALL_PATH" -name "realesrgan-ncnn-vulkan-*-ubuntu" -type d | sort | tail -1)
if [ "$LATEST_ESRGAN" ]; then
	if prompt "The script will attempt to download models from '$UPSCAYL_MODELS' and install them to '$LATEST_ESRGAN/models'."
	then
		get_latest_ergan_models "$LATEST_ESRGAN"
	fi
else
	warning "The script could not find a version of 'realesrgan-ncnn-vulkan' installed in '$INSTALL_PATH'."
fi
 
if prompt "The script will attempt to install 'videnh' to '$INSTALL_PATH/bin'."
then
	if rsync -a "videnh" "$INSTALL_PATH/bin/videnh"
	then
		echo "Successfully installed 'videnh' to '$INSTALL_PATH'"
	else
		warning "Failed to install 'videnh' to '$INSTALL_PATH'"
	fi
fi

printf "\nInstallation completed with [$WARNINGS] warnings.\n"
