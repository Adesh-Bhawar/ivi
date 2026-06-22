#!/bin/bash
#
# Script to setup, download and build the release for this project.
#
# Copyright (c) 2023-2024, Capgemini - Intelligent Devices
#

. /etc/os-release

# Use ${DBGLOG@P} to put out a debug message
DBGLOG='echo $0:${FUNCNAME[0]}():${LINENO}'

OS_VERSION="${NAME}-${VERSION_ID}"
OS_VERSION=${OS_VERSION/-/_}
OS_VERSION=${OS_VERSION/./_}

USAGE=`cat <<-USAGE_END
	$0 [-<option>] [--<option>] <command>\n
	Commands:\n
	\tinstalldeps\tInstall package dependencies\n
	\tsetup\t\tDownload required Yocto build\n
	\tbuildall\tPerform a full Yocto build\n
	\tbuild <recipe>\tBuild specified recipe\n
	\tbuildlinux\tBuild the Linux kernel - same as build virtual/kernel\n
	\tconfiglinux\tConfigure the Linux kernel using menuconfig\n
	\tdefconfig\tSetup default configurations for yocto build\n
	\tcreateimage <noremmc|emmc>\tCreate disk image to flash on target\n
	\tsam-ba\t\tFunctions using sam-ba\n
	\t\terase-nor - (dangerous) erase complete NOR Flash\n
	\t\tflash <noremmc|emmc> - flash to NOR+eMMC or only eMMC\n
	\t\treset\n
	\tshell\t\tSetup the environment and start a shell\n
	\tdevshell <recipe> Setup a development/debug environment for recipe\n
	\tlistpackages\tList packages going into the release\n
	\tlisttasks <recipe> List all defined tasks for a target\n
	\tdevtool <cmd> <recipe> Run the devtool command for a recipe\n
	\tclean <recipe>\tClean specified recipe\n
	\tcleansstate <recipe> Clean specified recipe +state+cache\n
	\tcleanall <recipe> Clean specified recipe +state+cache+downloads\n
	\thelp\t\tDisplay brief help information\n
	Options:\n
	\t--socvendor <vendor>\n
	\t\tbroadcom\n
	\t--soc <soc>\n
	\t\tbcm43455\n
	\t--yoctobranch <yocto_branch>\n
	\t\tkirkstone*\n
	\t\tscarthgap\n
	\t--aglbranch <agl_branch>\n
	\t\tunagi*\n
	\t\tmaster\n
	\t--debug - enable debug while building
USAGE_END
`

set_common_package_deps()
{

	PACKAGES="build-essential chrpath cpio debianutils diffstat file"
	PACKAGES+=" gawk gcc git iputils-ping libacl1 libcrypt-dev locales"
	PACKAGES+=" python3 python3-git python3-jinja2 python3-pexpect"
	PACKAGES+=" python3-pip python3-subunit socat texinfo unzip wget"
	PACKAGES+=" xz-utils zstd"

	# Additional packages to support development
	PACKAGES+=" git-lfs liblz4-tool repo curl"
	PACKAGES+=" mesa-common-dev libegl1-mesa libsdl1.2-dev xterm"
	PACKAGES+=" clang-tools"
}

set_package_deps_for_Ubuntu_24_04()
{
	set_common_package_deps
	PACKAGES+=" git-core pylint3"
}

install_deps()
{
	echo "Installing packages required by Yocto for ${NAME} ${VERSION_ID}"

	CMD="set_package_deps_for_$OS_VERSION"
	eval $CMD

	sudo apt-get update
	sudo apt-get install ${PACKAGES}
}

yocto_agl_build_init()
{
	cd ${ROOT_DIR}

	# 6. Inside the .templateconf file, you will need to modify the
	#    TEMPLATECONF variable to match the path to the meta-atmel layer
	#    "conf" directory:
	# location of default conf files changed in mchp scarthgap
	#DEFAULTCONF="local.conf.sample"
	#CONFSAMPLE=`cd ${PRJ_META} && find meta-mchp-mpu -name ${DEFAULTCONF}`
	#CONF=`dirname ${CONFSAMPLE}`
	#export TEMPLATECONF=${TEMPLATECONF:-../$META_DIR/${CONF}}

	# 7. Initialize build directory
	#source openembedded-core/oe-init-build-env build-${BOARD}

	# -f -> flag to force overwriting any existing configuration
	source meta-agl/scripts/aglsetup.sh -f -m ${BOARD} -b "build-${BOARD}" \
		${AGL_FEATURES}
}

# Perform a full build
yocto_build_all()
{
	pushd . > /dev/null

	yocto_agl_build_init

	time bitbake ${BBDBG} ${BUILDIMAGE}

	popd > /dev/null
}

yocto_list_packages()
{
	pushd . > /dev/null

	yocto_agl_build_init

	bitbake ${BBDBG} -s

	popd > /dev/null
}

# Build a specific recipe
yocto_build_recipe()
{
	pushd . > /dev/null

	echo "Build Target: $1"

	yocto_agl_build_init

	time bitbake ${BBDBG} $1

	popd > /dev/null
}

show_real_file_info()
{
	for f in $* ; do
		if [ ! -L $f ]; then
			ls -l $f
		fi
	done
}

# Show build output
show_build_files()
{
	# Set DEPLOY_DIR, ...
	sam_ba_init

	BUILD_OUTPUT_DIR="${DEPLOY_DIR}/images/${BOARD}"
	pushd . > /dev/null
	cd ${BUILD_OUTPUT_DIR}

	show_real_file_info *

	popd > /dev/null
}

# Setup the bitbake environment and run a shell
yocto_shell()
{
	pushd . > /dev/null

	echo "Setting up bitbake environment"

	yocto_agl_build_init

	${SHELL}

	popd > /dev/null
}

# Do a task
yocto_dotask()
{
	pushd . > /dev/null

	echo "Task mode: $1"

	yocto_agl_build_init

	MACHINE=${BOARD} bitbake ${BBDBG} -c $1

	popd > /dev/null
}

# Do a task for a specfic recipe
# $1 - task to perform - clean, cleansstate, cleanall, devshell
# $2 - recipe to run the task on
yocto_dotask_recipe()
{
	pushd . > /dev/null

	echo "${1^c} Target: $2"

	yocto_agl_build_init

	time bitbake ${BBDBG} -c $1 $2

	popd > /dev/null
}

# Run devtool commands
# $1 - devtool command to run - add, modify, upgrade, extract
# $2 - recipe to run the task on
yocto_devtool_recipe()
{
	pushd . > /dev/null

	echo "Running devtool ${1} for recipe ${2}"

	yocto_agl_build_init

	MACHINE=${BOARD} devtool $1 $2

	popd > /dev/null
}

yocto_config_linux()
{
	pushd . > /dev/null

	yocto_agl_build_init

	bitbake ${BBDBG} virtual/kernel -c menuconfig

	popd > /dev/null
}

yocto_defconfig()
{
	pushd . > /dev/null

	yocto_agl_build_init

	MACHINE=${BOARD} bitbake ${BBDBG} linux-mchp -c kernel_configme -f
	MACHINE=${BOARD} bitbake ${BBDBG} linux-mchp -c menuconfig
	cp .config ${ROOT_DIR}/${META_DIR}/recipies-kernel/linux/files/defconfig

	popd > /dev/null
}

# Note: In order to make git work with authenticated repositories a git helper
# needs to be configured.
get_meta_cgid_layer()
{
	META_CGID_GIT_OR_CP=${META_CGID_CP:="git"}
	META_CGID_GIT_SERVER="https://gs.capgemini.com"
	META_CGID_GIT="${META_CGID_GIT_SERVER}/garuda/${META_DIR}.git"
	META_CGID_BRANCH="${YOCTO_BRANCH}"
	META_CGID_CP_SRC="${HOME}/gs.capgemini.com/meta-cgid"

	if [ ${META_CGID_GIT_OR_CP} == "git" ]; then
		if [ ! -d $META_DIR ]; then
			# First time, perform clone
			echo "Cloning ${META_CGID_GIT} branch ${META_CGID_BRANCH}..."
			git clone ${META_CGID_GIT} -b ${META_CGID_BRANCH} \
					${META_DIR}
		else
			# Subsequently pull
			echo "Pulling ${META_DIR} branch ${META_CGID_BRANCH}..."
			cd ${META_DIR}
			git pull
			cd ..
		fi
	fi

	if [ ${META_CGID_GIT_OR_CP} == "cp" ]; then
		if [ ! -d ${META_CGID_CP_SRC} ]; then
			echo "${META_CGID_CP_SRC} source does not exist!"
			exit 1
		fi

		if [ -d ${META_DIR} ]; then
			# Directory already present - delete it
			echo "Removing existing ${META_DIR} directory!"
			rm -rf ${META_DIR}
		fi

		# Copy from source location
		echo "Copying ${META_DIR} from ${META_CGID_CP_SRC}"
		cp -R ${META_CGID_CP_SRC} .
	fi
}

# Create the ROOT_DIR and download required Yocto packages
yocto_agl_setup()
{
	# 0. Create agl/${AGL_BRANCH} directory
	if [ ! -d "${ROOT_DIR}" ]; then
		mkdir -p "${ROOT_DIR}"
	fi
	cd "${ROOT_DIR}"

	# 1. Get the manifest file and download the repos in it
	repo init -b ${AGL_BRANCH} -m ${AGL_MANIFEST_FILE} \
		-u ${AGL_MANIFEST_URL}
	repo sync

	# 5. Clone our $META_DIR layer with the proper branch ready
	#if [ ${META_DIR} == "meta-cgid" ]; then
	# 	get_meta_cgid_layer
	#fi
}

EDIT_APPARMOR_PROFILE="N"

setup_apparmor_bitbake()
{
	if [ ${VERSION_ID} != "24.04" ]; then
		return
	fi

	POKY_BITBAKE_BIN=$(realpath $(find . -name bitbake | grep bin))
	APPARMOR_BITBAKE=/etc/apparmor.d/bitbake

	if [ ! -f ${APPARMOR_BITBAKE} ]; then

		cat <<-ENDAPPARMOR > ${APPARMOR_BITBAKE}
		abi <abi/4.0>,
		include <tunables/global>

		# @{BITBAKE_PATHS} = ${POKY_BITBAKE_BIN}

		profile bitbake "/**/bitbake/bin/bitbake" flags=(unconfined) {
			# @{BITBAKE_PATHS} ix,

			userns,

			include if exists <local/bitbake>
		}
		ENDAPPARMOR

		sudo systemctl reload apparmor.service
	else
		if [ ${EDIT_APPARMOR_PROFILE,,} == "y" ]; then
			${DBGLOG@P} "-> Should not be here!"
			grep ${POKY_BITBAKE_BIN} ${APPARMOR_BITBAKE}
			if [ $? == 1 ]; then
				${DBGLOG@P}
				EOL="$"
				sed "0,/BITBAKE_PATHS/s|${EOL}| ${POKY_BITBAKE_BIN}|" ${APPARMOR_BITBAKE}
				sudo systemctl reload apparmor.service
			else
				echo "apparmor already setup for bitbake."
			fi
		fi
	fi
}

yocto_setup()
{
	pushd . > /dev/null

	yocto_agl_setup

	setup_apparmor_bitbake

	echo "Finished yocto_setup()..."

	popd > /dev/null
}

# Create the diskimage for flashing

create_diskimage_partitions()
{
	echo "TODO: Creating diskimage..."
	ROOTFS_END=".rootfs.tar.gz"

	ROOTFS_FILE=$(find "$ROOTFS_DIR" -type f -name "$ROOTFS_START*$ROOTFS_END")

	declare -a PART_SIZE
	declare -a PART_START_SECTOR
	declare -a PART_SIZE_IN_SECTORS
	declare -a PART_END_SECTOR
	declare -a PART_TYPE

	PART_SIZE[0]=64
	PART_START_SECTOR[0]=2048
	PART_SIZE_IN_SECTORS[0]=$(((PART_SIZE[0])*1024*1024/512))
	PART_END_SECTOR[0]=$((PART_START_SECTOR[0]+PART_SIZE_IN_SECTORS[0]-1))
	PART_TYPE[0]=b

	PART_SIZE[1]=256
	PART_START_SECTOR[1]=$((PART_END_SECTOR[0]+1))
	PART_SIZE_IN_SECTORS[1]=$(((PART_SIZE[1]-1)*1024*1024))/512
	PART_END_SECTOR[1]=$((PART_START_SECTOR[1]+PART_SIZE_IN_SECTORS[1]-1))
	PART_TYPE[1]=83

	# Create a (64MB + 256MB = 320) MB disk
	DISKSIZE=$((PART_SIZE[0]+PART_SIZE[1]))

	dd if=/dev/zero bs="${DISKSIZE}M" count=1 | tr "\000" "\377" > ${IMGFILE}
	#echo "1. Create a 64MB VFAT partition"
	#echo "2. Create a ext4 partition with the remaining disk space"
	#Device               Boot  Start    End Sectors  Size Id Type
	#nor_emmc_flash2.img1        2048 133119  131072   64M  b W95 FAT32
	#nor_emmc_flash2.img2      133120 655359  522240  255M 83 Linux

	PARTITIONS="size=+${PART_SIZE[0]}M,type=${PART_TYPE[0]}\nsize=+$((PART_SIZE[1]-1))M,type=${PART_TYPE[1]}"
	echo -e $PARTITIONS | sfdisk ${IMGFILE}

	echo "Setup loop device for W95 FAT32 partition..."
	sudo losetup -f $IMGFILE -o $((PART_START_SECTOR[0]*512)) --sizelimit $((PART_SIZE[0]*1024*1024))
	echo "Setup loop device for ext4 partition..."
	sudo losetup -f $IMGFILE -o $((PART_START_SECTOR[1]*512)) --sizelimit $(((PART_SIZE[1]-1)*1024*1024))

	p1loopdev=`losetup | grep $((PART_START_SECTOR[0]*512)) | awk '{ print $1 }'`
	p2loopdev=`losetup | grep $((PART_START_SECTOR[1]*512)) | awk '{ print $1 }'`

	echo "p1loopdev=${p1loopdev}"
	echo "p2loopdev=${p2loopdev}"

	sudo mkfs.vfat $p1loopdev
	sudo mkfs.ext4 $p2loopdev

	mkdir emmcmntp1 emmcmntp2

	echo "--- $p1loopdev $p2loopdev ---"

	echo "Mount $IMGFILE at emmcmntp1 emmcmntp2"
	sudo mount $IMGFILE emmcmntp1 -o loop,offset=$((PART_START_SECTOR[0]*512)),sizelimit=$((PART_SIZE_IN_SECTORS[0]*512))
	sudo mount $IMGFILE emmcmntp2 -o loop,offset=$((PART_START_SECTOR[1]*512)),sizelimit=$((PART_SIZE_IN_SECTORS[1]*512))
	sync
	echo "Done.."
	echo "----Untar rootfs from build in emmcmntp2-----"
	cd emmcmntp2
	sudo rm -rf *
	sudo tar -xf $ROOTFS_FILE
	sync
	cd ..
	echo "---Unmount the partitions----"
	sudo umount $PWD/emmcmntp1
	sudo umount $PWD/emmcmntp2
	sudo losetup -d $p1loopdev $p2loopdev
}

# $1 - type of image to flash.  emmc only or noremmc.
# $2 - location where to create the image
create_diskimage()
{
	echo "Creating $1 diskimage in $2..."

	if [ "$1" == "emmc" ]; then
		ROOTFS_DIR="${DEPLOY_DIR}/images/${board_name[3]}/"
		ROOTFS_START="${image_type[0]}-${board_name[3]}"
		IMGFILE="emmc_image.img"
	elif [ "$1" == "noremmc" ]; then
		ROOTFS_DIR="${DEPLOY_DIR}/images/${board_name[2]}/"
		ROOTFS_START="${image_type[0]}-${board_name[2]}"
		IMGFILE="noremmc_image.img"
	fi
	create_diskimage_partitions
}

create_image()
{
	sam_ba_init

	case $1 in
	"emmc")
		echo "Creating image for eMMC only..."
		create_diskimage $1 ${DEPLOY_DIR}
		;;
	"noremmc")
		echo "Creating image for NOR+eMMC..."
		create_diskimage $1 ${DEPLOY_DIR}
		;;
	*)
		echo "ERROR: Unknown image ($1) to create!"
		echo "Supported images are: emmc, noremmc"
		exit 1
		;;
	esac
}

create_secure_image()
{
	encrypt_and_sign_bootstrap
	encrypt_and_sign_uboot
	sign_linux_fit_image
}

flash_init()
{
	echo "flash_init()..."
}

flash_erase_nor()
{
	sam_ba_init

	# Erase QSPI Flash
	echo "This command will erase any serial numbers, keys, etc. that are"
	echo "stored on the device."
	echo "Are you sure you want to erase the whole QSPI NOR flash?"
	read yesorno
	sudo ${SAM_BA} -p ${SAM_BA_PORT} -b ${SAM_BA_BOARD} -a qspiflash \
		-c erase
}

flash_bootstrap_to_qspinor()
{
	sam_ba_init

	BOOTSTRAP_START=0x00000000
	BOOTSTRAP_LEN=0x00040000
	BOOTSTRAP_BIN="BOOT.BIN"

	# Erase Bootstrap Area
	echo "Erasing bootstrap area: ${BOOTSTRAP_START}:${BOOTSTRAP_LEN}..."
	sudo ${SAM_BA} -p ${SAM_BA_PORT} -b ${SAM_BA_BOARD} -a qspiflash \
		-c erase:${BOOTSTRAP_START}:${BOOTSTRAP_LEN}

	# Flash the Bootstrap image
	echo "Flashing bootstrap ${DEPLOY_DIR}/${BOOTSTRAP_BIN}..."
	sudo ${SAM_BA} -p ${SAM_BA_PORT} -b ${SAM_BA_BOARD} -a qspiflash \
		-c writeboot:${DEPLOY_DIR}/${BOOTSTRAP_BIN}
}

flash_uboot_to_qspinor()
{
	sam_ba_init

	UBOOT_START=0x00040000
	UBOOT_LEN=0x00101000
	UBOOT_BIN="u-boot.bin"

	UBOOT_ENV_START=0x00140000
	UBOOT_ENV_BIN="u-boot-env.bin"

	# Erase U-Boot Area
	echo "Erasing u-boot area: ${UBOOT_START}:${UBOOT_LEN}..."
	sudo ${SAM_BA} -p ${SAM_BA_PORT} -b ${SAM_BA_BOARD} -a qspiflash \
		-c erase:${UBOOT_START}:${UBOOT_LEN}

	# Flash u-boot
	echo "Flashing u-boot ${DEPLOY_DIR}/${UBOOT_BIN}..."
	sudo ${SAM_BA} -p ${SAM_BA_PORT} -b ${SAM_BA_BOARD} -a qspiflash \
		-c write:${DEPLOY_DIR}/${UBOOT_BIN}:${UBOOT_START}

	# Flash u-boot-env
	echo "Flashing u-boot-env ${DEPLOY_DIR}/${UBOOT_ENV_BIN}..."
	sudo ${SAM_BA} -p ${SAM_BA_PORT} -b ${SAM_BA_BOARD} -a qspiflash \
		-c write:${DEPLOY_DIR}/${UBOOT_ENV_BIN}:${UBOOT_ENV_START}
}

flash_diskimage_to_emmc()
{
	sam_ba_init

	# Flash the complete diskimage to emmc
	echo "Flashing image to eMMC ${DEPLOY_DIR}/${BOOTSTRAP_BIN}..."
	sudo ${SAM_BA} -p ${SAM_BA_PORT} -b ${SAM_BA_BOARD} -a sdmmc \
		-c write:${DEPLOY_DIR}/${DISKIMAGE}
}

flash()
{
	case $1 in
	"emmc")
		sam_ba_flash_diskimage_to_emmc
		;;
	"noremmc")
		sam_ba_flash_bootstrap_to_qspinor
		sam_ba_flash_uboot_to_qspinor
		sam_ba_flash_diskimage_to_emmc
		;;
	*)
		echo "ERROR: Unknown flash type command ($1)"
		exit 1
		;;
	esac
}

fuse_secure_keys()
{
	sam_ba_fuse_private_key
}

fuse_bootconfig()
{
	echo "$0: IMPLEMENT ME!"
}

fuse_securebootconfig()
{
	echo "$0: IMPLEMENT ME!"
}

# Reset the SAMA5 using sam_ba
# reset <mode>
# mode = standard | secure
target_reset()
{
	sam_ba_init

	bootconfig="0x00061FF7"
	if [ $1 == "secure" ]; then
		bootconfig="0x20061FF7"
	fi

	echo "1. writecfg:bscr:0x4 - using Backup Register 0" 
	sudo ${SAM_BA} -p ${SAM_BA_PORT} -b ${SAM_BA_BOARD} -a bootconfig \
		-c writecfg:bscr:0x4

	echo "2. writecfg:bureg0:0x00061FF7"
	sudo ${SAM_BA} -p ${SAM_BA_PORT} -b ${SAM_BA_BOARD} -a bootconfig \
		-c writecfg:bureg0:$bootconfig

	echo "Reset .."
	sudo ${SAM_BA} -p ${SAM_BA_PORT} -b ${SAM_BA_BOARD} -a reset
}

SUPPORTED_BOARDS=`cat <<-SUPPORTED_BOARDS_END
	Supported boards:
	\tam62xx-evm
	\taws-ec2-arm64
	\aws-ec2-x86-64
	\tbeaglebone-ai64
	\tbeagleplay
	\tebisu                      # Renesas RCar Ebisu
	\tgeneric-arm64
	\th3-salvator-x              # Renesas RCar Salvator/H3
	\th3ulcb                     # Renesas RCar H3
	\th3ulcb-kf                  # Renesas RCar H3 w Kingfisher Board
	\th3ulcb-nogfx               # Renesas RCar H3 w/o gfx blobs
	\timx8mq-evk                 # i.MX8 w etnaviv
	\tintel-corei7-64            # x86-64 (Intel flavour)
	\tj721e-evm                  # TI Jacinto 7 EVM
	\tjetson-agx-orin-devkit
	\tm3-salvator-x              # Renesas RCar Salvator/M3
	\tm3ulcb                     # Renesas RCar M3
	\tm3ulcb-kf                  # Renesas RCar M3 w Kingfisher Board
	\tm3ulcb-nogfx               # Renesas RCAR M3 w/o gfx blobs
	\tnanopc-t6
	\tqemuarm                    # Qemu ARM
	\tqemuarm64                  # Qemu AArch 64 (ARM 64bit)
	\tqemuriscv64                # Qemu RISC-V 64bit
	\tqemux86-64 *               # Qemu x86-64
	\traspberrypi4               # Raspberry Pi 4
	\traspberrypi5               # Raspberry Pi 5
	\traspberrypi5000            # Raspberry Pi 5000
	\ts4sk
	\tsparrow-hawk
	\tspider
	\tunmatched
	\tvirtio-aarch64             # Virtio Guest
	\tvisionfive2
SUPPORTED_BOARDS_END
`

display_supported_boards()
{
	echo -e "\t--board <target board>"
	echo -e ${SUPPORTED_BOARDS}
}

declare -a image_type
declare -a image_desc

image_type[0]="agl-ivi-demo-qt"
image_desc[0]="AGL IVI Demo using Qt GUI"
image_type[1]="agl-ivi-demo-html5"
image_desc[1]="AGL IVI Demo using HTML5 GUI"

display_supported_imagetypes()
{
	echo -e "\t--buildimage <image>"
	i=0
	while [ "${image_type[$((i))]}x" != "x" ]; do
		echo -e "\t    ${image_type[$((i))]} - ${image_desc[$((i))]}"
		i=$((i+1))
	done
}

declare -a feature_name
declare -a feature_desc

feature_name[0]="agl-demo"
feature_desc[0]="AGL Demo"
feature_name[1]="agl-devel"
feature_desc[1]="development features: agl-package-management"
feature_name[2]="pipewire"
feature_desc[2]="low-level A/V multimedia management framework"
feature_name[3]="flutter"
feature_desc[2]="agl-pipewire, agl-app-framework"

display_supported_features()
{
	echo -e "\t--aglfeatures <features>"
	i=0
	while [ "${feature_name[$((i))]}x" != "x" ]; do
		echo -e "\t    ${feature_name[$((i))]} - ${features_desc[$((i))]}"
		i=$((i+1))
	done
}

display_environment_variables()
{
	echo " Environment Variables:"
	echo -e "\tMETA_CGID_CP\tIf unset, null or git, get meta-cgid from git,"
	echo -e "\t\t\telse copy it from ~/gs.capgemini.com/meta-cgid"
}

display_params()
{
	echo "======= BUILDER PARAMETERS ======="
	echo "SOCVENDOR=$SOCVENDOR"
	echo "SOC=$SOC"
	echo "BOARD=$BOARD"
	echo "META_DIR=${META_DIR}"
	echo "YOCTO_BRANCH=${YOCTO_BRANCH}"
	echo "AGL_BRANCH=${AGL_BRANCH}"
	echo "AGL_FEATURES=${AGL_FEATURES}"
	echo "BUILDIMAGE=$BUILDIMAGE"
	echo "ROOT_DIR=$ROOT_DIR"
	echo "DL_DIR=${DL_DIR}"
	echo "SSTATE_DIR=${SSTATE_DIR}"
	echo "=================================="
}

display_usage()
{
	echo -e $USAGE
	display_supported_boards
	display_supported_features
	display_supported_imagetypes
	display_environment_variables
}

# Default Build Settings
# Change these to represent the default build for your project
BOARD=raspberrypi5
SOCVENDOR=broadcom
SOC=bcm43455
AGL_TOP="agl"
AGL_BRANCH="unagi"

# Default build with Qt IVI Demo
AGL_FEATURES="agl-demo agl-devel"
BUILDIMAGE="agl-ivi-demo-qt"
# Build HTML5 IVI Demo
#AGL_FEATURES="agl-demo agl-devel agl-profile-graphical-html5"
#BUILDIMAGE="agl-ivi-demo-html5"

# Macros for using linux4microchip and scarthgap branch of yocto
YOCTO_GIT="https://git.yoctoproject.org/poky"
YOCTO_BRANCH="scarthgap"
YOCTO_TAG=("yocto-4.0.17" "scarthgap-5.0.3")
OE_GIT="https://git.openembedded.org/meta-openembedded"
OE_BRANCH="${YOCTO_BRANCH}"
OE_TAG=("8bb165" "735ae0")
ARM_GIT="https://git.yoctoproject.org/meta-arm"
ARM_BRANCH="${YOCTO_BRANCH}"
ARM_TAG=("yocto-4.0.2" "yocto-5.0")
AGL_MANIFEST_URL="https://gerrit.automotivelinux.org/gerrit/AGL/AGL-repo"
AGL_MANIFEST_FILE="unagi_21.0.1.xml"

BBDBG=""

ROOT_DIR="${AGL_TOP}-${AGL_BRANCH}-${YOCTO_BRANCH}"
ROOT_PATH=`pwd`/${ROOT_DIR}
DL_DIR_NAME="common-downloads"

export DL_DIR=${ROOT_PATH}/${DL_DIR_NAME}
export LC_ALL="en_US.utf8"
export SSTATE_DIR="${ROOT_PATH}/sstate-cache/"

if [[ $# -eq 0 ]]; then
	display_usage
	exit 1
fi

while [[ $# -gt 0 ]]; do
	case $1 in
	"--board")
		BOARD=$2
		shift 2
		;;
	"--agl-tag")
		AGL_TAG=$2
		shift 2
		;;
	"--yoctobranch")
		YOCTO_BRANCH=$2
		OE_BRANCH="${YOCTO_BRANCH}"
		ARM_BRANCH="${YOCTO_BRANCH}"
		shift 2
		;;
	"--aglbranch")
		AGL_BRANCH=$2
		ROOT_DIR="${AGL_TOP}-${AGL_BRANCH}-${YOCTO_BRANCH}"
		ROOT_PATH=`pwd`/${ROOT_DIR}
		shift 2
		;;
	"--debug")
		BBDBG="--debug"
		shift
		;;
	"--aglfeatures")
		AGL_FEATURES=$2
		shift 2
		;;
	"--buildimage")
		BUILDIMAGE=$2
		shift 2
		;;
	"--sam-ba-port")
		SAM_BA_PORT=$2
		shift 2
		;;
	"--help"|"help")
		display_usage
		display_params
		exit 0
		;;
	"installdeps")
		# 1. Install build dependencies
		install_deps
		shift
		;;
	"setup")
		# 2. Download the required recipes
		display_params
		yocto_setup
		shift
		;;
	"buildall")
		# 3. Build the full release
		display_params
		yocto_build_all
		shift
		;;
	"build")
		# Build a specified recipe
		TARGET=${2}
		display_params
		yocto_build_recipe ${TARGET}
		shift 2
		;;
	"show-build")
		display_params
		show_build_files
		shift
		;;
	"buildlinux")
		display_params
		yocto_build_recipe virtual/kernel
		shift
		;;
	"defconfig")
		display_params
		yocto_defconfig
		shift
		;;
	"configlinux")
		display_params
		yocto_config_linux
		shift
		;;
	"createimage")
		display_params
		create_image $2
		shift 2
		;;
	"erase-nor")
		display_params
		sam_ba_erase_nor
		;;
	"flash")
		display_params
		sam_ba_flash_image $2
		shift
		;;
	"reset")
		display_params
		sam_ba_sama5_reset standard
		shift
		;;
	"securereset")
		display_params
		sam_ba_sama5_reset secure
		shift
		;;
	"shell")
		display_params
		yocto_shell
		shift
		;;
	"devshell" | "clean" | "cleansstate" | "cleanall")
		display_params
		if [ $# -gt 1 ]; then
			yocto_dotask_recipe $1 $2
			shift 2
		else
			echo "Command $1 should be followed by a recipe name"
			exit 1
		fi
		;;
	"listpackages")
		display_params
		yocto_list_packages
		shift
		;;
	"listtasks")
		display_params
		yocto_dotask $1
		shift
		;;
	"devtool")
		display_params
		yocto_devtool_recipe $2 $3
		shift 3
		;;
	-*|--*)
		echo "Unknown option $1"
		display_usage
		exit 1
		;;
	*)
		echo "Unknown command $1"
		display_usage
		exit 1
		;;
	esac
done

