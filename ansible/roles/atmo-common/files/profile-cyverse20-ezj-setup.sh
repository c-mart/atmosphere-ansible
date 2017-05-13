#!/bin/bash 

# NOTE: if you change this, you must change it below as well
INSTALL_ROOT=/home

#############################
# begin sudo anaconda_install
#############################
export sudo_anaconda_install='
ANACONDA_VERSION=4.3.1
INSTALL_ROOT=/home
python_detect () {
	if [ -n "$pversion" -a $pversion -ne 0 ]; then
		PYTHON_VERSION=$pversion
	else
		which python3
		if [ $? -eq 0 ]; then
			PYTHON_VERSION=3
		else
			PYTHON_VERSION=2
		fi
	fi
	echo "DEBUG: using python version $PYTHON_VERSION"
}

anaconda_update () {
	echo "DEBUG: attempting to update anaconda"
	${ANACONDA_ROOT}/bin/conda update --prefix ${ANACONDA_ROOT} -y anaconda
}

anaconda_install () {

	# set the INSTALL_ROOT if found
	if [ -n "$install_root" ]; then
		INSTALL_ROOT=$install_root
	fi

	ANACONDA_ROOT=${INSTALL_ROOT}/anaconda${PYTHON_VERSION}
	lastdir=$PWD
	echo "DEBUG: downloading anaconda binary, may take a few minutes"
	cd ${INSTALL_ROOT}
	if [ ! -f ${INSTALL_ROOT}/Anaconda${PYTHON_VERSION}-${ANACONDA_VERSION}-Linux-x86_64.sh ]; then
		wget --quiet https://repo.continuum.io/archive/Anaconda${PYTHON_VERSION}-${ANACONDA_VERSION}-Linux-x86_64.sh
		if [ $? -ne 0 ]; then
			echo "ERROR: Could not download https://repo.continuum.io/archive/Anaconda${PYTHON_VERSION}-${ANACONDA_VERSION}-Linux-x86_64.sh"
		fi
	fi

	# only bash install if the directory doesnt already exist
	if [ -e "Anaconda${PYTHON_VERSION}-${ANACONDA_VERSION}-Linux-x86_64.sh" ]; then
		if [ ! -d "$ANACONDA_ROOT" ]; then 
			echo "DEBUG: install Anaconda"
			bash Anaconda${PYTHON_VERSION}-${ANACONDA_VERSION}-Linux-x86_64.sh -b -p ${ANACONDA_ROOT}
		else
			echo "DEBUG: Anaconda already installed to $ANACONDA_ROOT"
		fi 

		# if r-install is detected do the following
		if [ -n "$rkernel" -a "$rkernel" -eq 1 ]; then
			echo "DEBUG: installing rkernel"
			${ANACONDA_ROOT}/bin/conda install -y -c r r-essentials
		fi
	fi

	if [ -n "$update_enabled" -a "$update_enabled" -eq 1 ]; then
		anaconda_update
	fi

	cd $lastdir
}

jupyter_notebook_launch () {
	if [ -n "$ANACONDA_IS_SET" ]; then
		cyverse_public_ip
		jupyter-notebook --no-browser --ip=0.0.0.0 2>&1 | sed s/0.0.0.0/${CYVERSE_PUBLIC_IP}/g
	else
		echo "Anaconda is not installed, cannot run jupyter-notebook"
	fi
}

python_detect $1
anaconda_install
'
###########################
# end sudo anaconda_install
###########################

python_detect () {
	if [ -n "$1" -a "$1" -ne 0 ]; then
		PYTHON_VERSION=$1
	else
		which python3
		if [ $? -eq 0 ]; then
			PYTHON_VERSION=3
		else
			PYTHON_VERSION=2
		fi
	fi
	echo "DEBUG: using python version $PYTHON_VERSION"
}

anaconda_setpath () {
	python_detect $1
	ANACONDA_ROOT=${INSTALL_ROOT}/anaconda${PYTHON_VERSION}
	if [ -n "$ANACONDA_ROOT" ]; then
		export PATH="${ANACONDA_ROOT}/bin:${PATH}"
		export ANACONDA_IS_SET=1
	fi
}

jupyter_notebook_launch () {
	if [ -n "$ANACONDA_IS_SET" ]; then
		cyverse_public_ip
		${ANACONDA_ROOT}/bin/jupyter-notebook --no-browser --ip=0.0.0.0 2>&1 | sed s/0.0.0.0/${CYVERSE_PUBLIC_IP}/g
	else
		echo "Anaconda is not installed, cannot run jupyter-notebook"
	fi
}

ezj () {
	local OPTIND opt

	update_option=0
	r_option=0
	quick=0
	pv=0
	option_error=0
	while getopts "qrRu23p:" opt; do
		case $opt in
		q)
			echo "DEBUG: option for quick launch enabled"
			quick=1
			;;
		r)
			echo "DEBUG: option to install R kernel enabled"
			r_option=1
			;;
		R)
			echo "DEBUG: option to install R kernel enabled"
			r_option=1
			;;
		u)
			echo "DEBUG: option to update anaconda enabled"
			update_option=1
			;;
		p)
			if [ -n "$OPTARG" -a -d "$OPTARG" ]; then
				echo "DEBUG: changing INSTALL_ROOT to $OPTARG" 
				INSTALL_ROOT=$OPTARG
			else
				echo "ERROR: invalid INSTALL_ROOT = $OPTARG"
				option_error=1
			fi
			;;
		2)
			if [ "$pv" -ne 0 ]; then
				echo "ERROR: options -2 and -3 cannot be combined"
				option_error=1
			else
				echo "DEBUG: forcing Python 2"
				pv=2
			fi
			;;
		3)
			if [ "$pv" -ne 0 ]; then
				echo "ERROR: options -2 and -3 cannot be combined"
				option_error=1
			else
				echo "DEBUG: forcing Python 3"
				pv=3
			fi
			;;
		\?)
			echo "invalid flag -$OPTARG"
			;;
		esac
	done

	if [ $option_error -eq 0 ]; then
		if [ $quick -eq 0 ]; then
			sudo bash -c "eval export update_enabled=${update_option};export rkernel=${r_option};export pversion=${pv};install_root=${INSTALL_ROOT};$sudo_anaconda_install"
		fi
		anaconda_setpath $pv
		jupyter_notebook_launch
	fi
}

alias ez="echo '
Here are the different ez commands:

ez   -> this help menu
ezj  -> run jupyter-notebook with python detection

Options to pass to 'ezj':
-q	do not attempt to install, just launch jupyter!
-R	install the R kernel (-r also works)
-2	force python 2 kernel (not compatible with -3 option)
-3	force python 3 kernel (not compatible with -2 option)
-u	force update of anaconda (default is no update)
-p	takes a directory as an option; install in a different location other than default ($INSTALL_ROOT)
	NOTE: if you set this, you must pass it again for future calls

Example of options

	ezj -u -R
	ezj -p /opt -u

'"
