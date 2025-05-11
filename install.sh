#! /bin/bash

readonly INSTALL_PATH="/usr/local"
readonly ESRGAN_REPO="https://api.github.com/repos/xinntao/Real-ESRGAN/releases"
readonly RIFE_REPO="https://api.github.com/repos/nihui/rife-ncnn-vulkan/releases"
readonly UPSCAYL_MODELS="https://github.com/upscayl/custom-models/archive/refs/heads/main.zip"
WARNINGS=0
NO_PROMPT=n

warning () {
	((WARNINGS++))
	printf "Warning [%s]: %s\n" "$WARNINGS" "$1" 1>&2
}

error () {
	printf "Error: %s\n" "$1" 1>&2
	printf "Installation failed.\n" 1>&2
	exit 1
}

function prompt() {
	if [ "$NO_PROMPT" == y ]; then
		return 0;
	fi

	printf "\n%s\n" "$1"
    read -rp "Do you wish to continue with this step? ([y]es/[N]o): "
    case $(echo "$REPLY" | tr '[:upper:]' '[:lower:]') in
        y|yes) return 0 ;;
        *)     printf "Skipped.\n"; return 1 ;;
    esac
}
export -f prompt


########################################################
### Download and install releases from GitHub repos ####
########################################################

download_latest_release() {
	local URL="$1"
	local DIRECTORY="$2"
	local ARCHIVE="$3"
	
	# Check if we got a URL
	if [ ! "$URL" ]; then
		# This is usually an API error -- try later or DIY
		warning "Failed to find latest release. Try again later or try a manual install."
		return 1
	else
		# Check if the latest version is already installed
		if [ -d "$INSTALL_PATH/$DIRECTORY" ]; then
			warning "The latest release '$DIRECTORY' already exists in '$INSTALL_PATH'. Cancelling download."
			return 1
		fi
	
		# Check if we already downloaded the archive
		if [ ! -f "$ARCHIVE" ]; then
			# Try downloading the archive
			if ! wget -q --show-progress --progress=bar:force "$URL"
			then
				warning "Failed to download latest release from '$URL'"
				return 1
			fi
		fi
	fi
	
	return 0
}

unzip_latest_release() {
	local EXECUTABLE="$1"
	local DIRECTORY="$2"
	local ARCHIVE="$3"
	
	# Try to unzip the archive
	printf "Extracting '%s'\n" "$ARCHIVE"
	
	if 
		unzip -qod "$DIRECTORY" "$ARCHIVE"
	then
		# Check if we need to move directory structure down a notch
		if [ -d "$DIRECTORY/$DIRECTORY" ]; then
			if ! rsync -a ./"$DIRECTORY/$DIRECTORY" ./
			then
				warning "Failed to create the correct folder structure for '$DIRECTORY'"
				return 1
			fi
		fi
		# Clean up
		chmod +x "$DIRECTORY/$EXECUTABLE"	
		rm -v "$ARCHIVE"
	else
		warning "Failed to unzip the archive '$ARCHIVE'"
		return 1
	fi
	
	return 0
}

install_latest_release() {
	local EXECUTABLE="$1"
	local DIRECTORY="$2"
	local ARCHIVE="$3"
	
	# Try to install the files to $INSTALL_PATH
	if 
		rsync -a "$DIRECTORY" "$INSTALL_PATH" && 
		ln -vfs "$INSTALL_PATH/$DIRECTORY/$EXECUTABLE" "$INSTALL_PATH/bin/$EXECUTABLE"
	then
		rm -rf "$DIRECTORY"
		printf "Successfully installed '%s' to '%s'\n" "$EXECUTABLE" "$INSTALL_PATH"
	else
		warning "Failed to install '$EXECUTABLE' to '$INSTALL_PATH'"
		return 1
	fi
	
	return 0
}

get_latest_release () {
	local URL
	local ARCHIVE
	local DIRECTORY
	local EXECUTABLE
	
	# Fetch the URL to the latest zip release for Ubuntu and set some 
	# variables based on that.
	URL=$(curl -s "$1" | grep browser_download_url | grep "ubuntu" | head -1 | cut -d '"' -f 4)
	ARCHIVE="$(basename "$URL")"
	DIRECTORY="${ARCHIVE%.*}"
		[[ $DIRECTORY =~ ([a-zA-Z.-_%+-]+)-([0-9]+-ubuntu) ]]
	EXECUTABLE="${BASH_REMATCH[1]}"
			
	if 
		download_latest_release "$URL" "$DIRECTORY" "$ARCHIVE" &&
		unzip_latest_release "$EXECUTABLE" "$DIRECTORY" "$ARCHIVE" &&
		install_latest_release "$EXECUTABLE" "$DIRECTORY" "$ARCHIVE"
	then
		return 0
	fi
	
	return 1
}

######################################################
### Download and install additional ESRGAN models ####
######################################################

download_latest_esrgan_models() {
	local ARCHIVE="$1"

	# Check if we already downloaded the archive
	if [ ! -f "$ARCHIVE" ]; then
		# Try downloading the archive
		if 
			! wget -q --show-progress --progress=bar:force "$UPSCAYL_MODELS" -O "$ARCHIVE"
		then
			warning "Failed to download latest models from '$UPSCAYL_MODELS'"
			return 1
		fi
	fi
	
	return 0
}

unzip_latest_esrgan_models() {
	local ARCHIVE="$1"

	# Try to unzip the archive
	printf "Extracting '%s'\n" "$ARCHIVE"
	
	if 
		unzip -qo "$ARCHIVE"
	then
		rm -v "$ARCHIVE"
	else
		warning "Failed to unzip the archive '$ARCHIVE'"
		return 1
	fi
	
	return 0
}

install_latest_esrgan_models() {
	local ARCHIVE="$1"
	local DIRECTORY="$2"
	local ESRGAN_VERSION="$3"

	# Try to install the files to $INSTALL_PATH
	if 
		rsync -a "$DIRECTORY/models" "$ESRGAN_VERSION"
	then
		rm -rf "$DIRECTORY"
		printf "Successfully installed models to '%s'\n" "$ESRGAN_VERSION/models"
	else
		warning "Failed to install models to '$ESRGAN_VERSION/models'"
		return 1
	fi
	
	return 0
}

get_latest_esrgan_models() {
	local ESRGAN_VERSION="$1"
	local DIRECTORY="custom-models-main"
	local ARCHIVE="$DIRECTORY.zip"
	
	if
		download_latest_esrgan_models "$ARCHIVE" &&
		unzip_latest_esrgan_models "$ARCHIVE" &&
		install_latest_esrgan_models "$ARCHIVE" "$DIRECTORY" "$ESRGAN_VERSION"
	then 
		return 0
	fi

	return 1
}

######################
### Main function ####
######################

print_help () {
	printf "Help\n"
}

main() {
	local INSTALL_REALESRGAN=n
	local INSTALL_RIFE=n
	local INSTALL_VIDENH=n
	local INSTALL_MODELS=n
	local OPTIONS=n
	local LONGOPTS=n
	
	OPTIONS=ayh
	LONGOPTS=all,realesrgan,rife,videnh,models,yes,help
	
	if [[ $EUID -gt 0 ]]; then  
		error "Please run with sudo: 'sudo ./install'"
	fi

	# Install some dependencies
	if ! apt install curl ffmpeg imagemagick rsync unzip util-linux wget
	then
		warning "apt does not seem to be available on this system, make sure dependancies are met"
	fi
	
	! getopt --test > /dev/null
	if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
		printf "I’m sorry, 'getopt --test' failed in this environment.\n"
		exit 1
	fi

	! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
	if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
		# Invalid option
		printf "Invalid option.\n"
		exit 1
	fi

	eval set -- "$PARSED"

	while true; do
		case "$1" in
		    --realesrgan)
		    	INSTALL_REALESRGAN=y
		        shift
		        ;;
		    --rife)
		    	INSTALL_RIFE=y
		        shift
		        ;;
		    --videnh)
		    	INSTALL_VIDENH=y
		        shift
		        ;;
		    --models)
		    	INSTALL_MODELS=y
		        shift
		        ;;
		    -a|--all)
		    	INSTALL_REALESRGAN=y
		    	INSTALL_RIFE=y
		    	INSTALL_VIDENH=y
		    	INSTALL_MODELS=y
		    	shift
		    	;;
		    -y|--yes)
		    	NO_PROMPT=y
		        shift
		        ;;
		    -h|--help)
		    	print_help
		        exit 0
		        ;;
		    --)
		    	shift
		        if [[ "$1" != "" ]]; then
		        	printf "Unrecognized argument '$1'.\n"
		        	exit 1
		        fi
		    	break
		    	;;
		    *)
		        printf "Programming error\n"
		        exit 1
		        ;;
		esac
	done

	# Download and install from esrgan github repo
	if [ "$INSTALL_REALESRGAN" == y ]; then
		if prompt "The script will attempt to download the latest release from '$ESRGAN_REPO' and install it to '$INSTALL_PATH'."
		then
			get_latest_release "$ESRGAN_REPO"
		fi
	fi
	
	# Download and install from rife github repo
	if [ "$INSTALL_RIFE" == y ]; then
		if prompt "The script will attempt to download the latest release from '$RIFE_REPO' and install it to '$INSTALL_PATH'."
		then
			get_latest_release "$RIFE_REPO"
		fi
	fi

	# Download and install additional esrgan models for the latest version installed in $INSTALL_PATH
	if [ "$INSTALL_MODELS" == y ]; then
		LATEST_ESRGAN=$(find "$INSTALL_PATH" -name "realesrgan-ncnn-vulkan-*-ubuntu" -type d | sort | tail -1)
		if [ "$LATEST_ESRGAN" ]; then
			if prompt "The script will attempt to download models from '$UPSCAYL_MODELS' and install them to '$LATEST_ESRGAN/models'."
			then
				get_latest_esrgan_models "$LATEST_ESRGAN"
			fi
		else
			warning "The script could not find a version of 'realesrgan-ncnn-vulkan' installed in '$INSTALL_PATH'."
		fi
	fi
	
	if [ "$INSTALL_VIDENH" == y ]; then
		if prompt "The script will attempt to install 'videnh' to '$INSTALL_PATH/bin'."
		then
			if rsync -a "videnh" "$INSTALL_PATH/bin/videnh"
			then
				printf "Successfully installed 'videnh' to '%s'\n" "$INSTALL_PATH"
			else
				warning "Failed to install 'videnh' to '$INSTALL_PATH'"
			fi
		fi
	fi

	printf "\nScript completed with [%s] warnings.\n" "$WARNINGS"
}

main "$@"
exit 0
