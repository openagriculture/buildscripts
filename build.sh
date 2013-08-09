#!/bin/sh

# Build Enviroment Setup Script
#
# Copyright (C) 2011,2012 Freescale Semiconductor
# Copyright (C) 2013 [ Shivdas Gujare ] shivdas.gujare@gmail.com / shivdas.gujare@arputer.com
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA


datetime=$(date +%d%m%y-%I%M)
buildscripts_dir=$PWD

install_repo() {
	if [ -f ~/bin/repo ]
	then
		echo "repo is installed. continuting repo sync"
	else
		mkdir -p ~/bin
		CURL=`which curl`
		$CURL https://dl-ssl.google.com/dl/googlesource/git-repo/repo > ~/bin/repo
		chmod a+x ~/bin/repo
	fi
}

download_metadata() {
	cd $build_dir
	~/bin/repo init -u https://github.com/openagriculture/manifest.git -b $machine
	~/bin/repo sync
}

usage() {
# Help Screen
echo ""
echo "Usage: sh build.sh -m <machine>"
echo ""
echo ""
echo "The <machine> argument can be one of the following"
echo "       beagleboard:   BeagleBoard"
echo "
    * [-m machine]:  supported machine for which BSP can be build.
    * [-j jobs]:  number of jobs for make to spawn during the compilation stage.
    * [-t tasks]: number of BitBake tasks that can be issued in parallel.
    * [-d path]:  non-default DL_DIR path (download dir)
    * [-b path]:  non-default build dir location
    * [-h]:       help
"
echo ""
}

clean_up() {
	unset machine n_jobs n_threads f_help f_error   
}

setup_local_conf() {
cat >> $PROJECT_DIR/conf/local.conf <<_EOF
MACHINE = "$machine"
DISTRO = "anar"
# Parallelism Options
BB_NUMBER_THREADS = "$THREADS"
PARALLEL_MAKE = "-j $JOBS"
PACKAGE_CLASSES = "package_ipk"
DL_DIR = "$PROJECT_DIR/../sources"
SSTATE_DIR = "$PROJECT_DIR/../sstate-cache"
_EOF
}

setup_bblayers_conf() {
sed "/  \"/d" $PROJECT_DIR/conf/bblayers.conf > $PROJECT_DIR/conf/bblayers.conf~
mv $PROJECT_DIR/conf/bblayers.conf~ $PROJECT_DIR/conf/bblayers.conf

while read line
do
	meta_layer=$line
if [ -e $METADATA_DIR/$meta_layer ]; then
	META_LAYER_PATH="$METADATA_DIR/$meta_layer"
	echo "  $META_LAYER_PATH \\" >> $PROJECT_DIR/conf/bblayers.conf
fi
done < $buildscripts_dir/meta-layers

echo "  \"" >> conf/bblayers.conf
}


check_local_sources() {
while read line
do
external_sources_dir=$line
if [ -d $external_sources_dir ]; then
cat >> $PROJECT_DIR/conf/local.conf <<_EOF
SOURCE_MIRROR_URL = "file://$external_sources_dir
INHERIT += "own-mirrors"
BB_GENERATE_MIRROR_TARBALLS = "1"
_EOF
fi
done < $buildscripts_dir/external/sources
}

initialize_vars() {
	build_dir=$PWD/../$machine-$datetime
	mkdir -p $build_dir

	if test $build_path; then
        	PROJECT_DIR=${build_path}
	else
        	PROJECT_DIR=$build_dir/build_${machine}_release
	fi

	METADATA_DIR=$build_dir/metadata
	POKY_DIR=$METADATA_DIR/poky

	# set default jobs and threads
	JOBS="2"
	THREADS="2"
	# Validate optional jobs and threads
	if [ -n "$n_jobs" ] && [[ "$n_jobs" =~ ^[0-9]+$ ]]; then
		JOBS=$n_jobs
	fi
	if [ -n "$n_threads" ] && [[ "$n_threads" =~ ^[0-9]+$ ]]; then
		THREADS=$n_threads
	fi
}

set_environments() {
	echo "Creating an yocto build output at $PROJECT_DIR"
	source $POKY_DIR/oe-init-build-env $PROJECT_DIR > /dev/null

	# make a SOURCE_THIS (setenv) file
	echo "#!/bin/sh" >> $build_dir/setenv
	echo ". ${POKY_DIR}/oe-init-build-env $PROJECT_DIR > /dev/null" >> $build_dir/setenv
	chmod a+x $build_dir/setenv
}

verify_buildsetup() {

# check the "-h" and other not supported options
if test $f_error || test $f_help; then
    usage && clean_up
    exit 1
fi

# check if xz if available
if [ -z "`which xz`" -o -z "`which chrpath`" -o -z "`which gcc`" -o -z "`which make`" ];then
    echo "
    ERROR: Please run script 'metadata/poky/scripts/host-prepare.sh' first.
    "
    clean_up
    exit 1
fi

}

# get command line options
OLD_OPTIND=$OPTIND
while getopts "m:j:t:h" arguments
do
    case $arguments in
        m) machine="$OPTARG" ;;
        j) n_jobs="$OPTARG"  ;;
        t) n_threads="$OPTARG" ;;
        h) f_help='true' ;;
        ?) f_error='true' ;;
    esac
done

verify_buildsetup
install_repo
initialize_vars
download_metadata
set_environments
setup_local_conf
check_local_sources
setup_bblayers_conf
