#!/bin/bash

set -e
workdir=$(readlink -f $(dirname $0))
xsadir=${workdir}/../hw/pre-built
recipesdir=${workdir}/meta-vitis/
plnxdir=${workdir}/xilinx-zcu102-trd
zcu102_bsp=${workdir}/xilinx-zcu102-v2022.2-10141622.bsp

PKG_OPTIONAL=( \
	resize-part \
	dnf \
	nfs-utils \
	cmake \
	opencl-headers \
	opencl-clhpp-dev \
	packagegroup-petalinux-x11 \
	packagegroup-petalinux-opencv \
	packagegroup-petalinux-gstreamer \
	packagegroup-petalinux-self-hosted \
	vitis-ai-library \
	vitis-ai-library-dev \
	vitis-ai-library-dbg \
	resnet50 \
)

echo_info() {
	echo -e "\033[42;30mINFO: $@\033[0m"
}

echo_error() {
	echo -e "\033[41;30mERROR: $@\033[0m"
}

create_proj() {
	#set petalinux tools
	if [ "$PETALINUX" == "" ]; then
		echo_error "Please set petalinux tools before start"
		exit 1
	fi

	cd ${workdir}
	# check xsa 
	if [ ! -e "$zcu102_bsp" ]; then
		echo_info "download zcu102 released bsp..."
		wget -c https://xilinx-ax-dl.entitlenow.com/dl/ul/2022/10/17/R210702260/xilinx-zcu102-v2022.2-10141622.bsp\?hash\=oji95zhvEoW1xcFI21oS0g\&expires\=1671623799\&filename\=xilinx-zcu102-v2022.2-10141622.bsp -O xilinx-zcu102-v2022.2-10141622.bsp
	fi

	if [ "2b608a38b5ba9e9aa9b11eca0c980893" != "$(md5sum $zcu102_bsp | cut -d' ' -f1)" ]; then
		echo_error "Auto download bsp failed!"
		echo_info "Please download bsp from https://www.xilinx.com/member/forms/download/xef.html?filename=xilinx-zcu102-v2022.2-10141622.bsp"
		echo_info "Please copy /path/to/your/downloads/xilinx-zcu102-v2022.2-10141622.bsp to $zcu102_bsp"
		exit 1
	fi

	# create and config a petalinux project, and rename project with ${plnxdir}
	if [ -d "${plnxdir}" ];then
		echo_info "deleting old petalinux project..."
		rm -rf ${plnxdir}
	fi

	petalinux-create -t project -s $zcu102_bsp  && sync
	if [ -d "${workdir}/xilinx-zcu102-2022.2" ];then
		mv ${workdir}/xilinx-zcu102-2022.2   ${plnxdir}
	else
		echo_error "petalinux create project failed"
		exit 1
	fi

	if [ -f ${xsadir}/top_wrapper.xsa ]; then
		cd ${plnxdir} && petalinux-config --get-hw-description=${xsadir} --silentconfig
	else
		echo_error "No XSA files found under path ${xsadir}"
		exit 1
	fi
}

customize_proj()
{
	# 2.2.1 enable dpu driver & linux-xlnx master
	echo_info "> enable dpu driver"
	cp -arf ${recipesdir}/recipes-kernel ${plnxdir}/project-spec/meta-user/

	# 2.2.2 disable zocl & xrt
	echo_info "> disable zocl & xrt for vivado flow"
	sed -i 's/CONFIG_xrt=y/\# CONFIG_xrt is not set/' ${plnxdir}/project-spec/configs/rootfs_config
	sed -i 's/CONFIG_xrt-dev=y/\# CONFIG_xrt-dev is not set/' ${plnxdir}/project-spec/configs/rootfs_config
	sed -i 's/CONFIG_zocl=y/\# CONFIG_zocl is not set/' ${plnxdir}/project-spec/configs/rootfs_config

	# 2.2.3 install recommended packages to rootfs
	echo_info "> add packages installed to rootfs"
	cp -arf ${recipesdir}/recipes-apps ${plnxdir}/project-spec/meta-user/
	cp -arf ${recipesdir}/recipes-core ${plnxdir}/project-spec/meta-user/
	cp -arf ${recipesdir}/recipes-vitis-ai ${plnxdir}/project-spec/meta-user/

	for ((item=0; item<${#PKG_OPTIONAL[@]}; item++))
	do
		echo "IMAGE_INSTALL:append=\" ${PKG_OPTIONAL[item]} \""   >> ${plnxdir}/project-spec/meta-user/conf/petalinuxbsp.conf
	done

	# 2.2.3 enable package management and auto login
	echo_info "> enable auto login and package management"
	sed -i '/# CONFIG_imagefeature-package-management is not set/c CONFIG_imagefeature-package-management\=y' ${plnxdir}/project-spec/configs/rootfs_config
	sed -i '/# CONFIG_imagefeature-debug-tweaks is not set/c CONFIG_imagefeature-debug-tweaks\=y'		${plnxdir}/project-spec/configs/rootfs_config
	sed -i '/# CONFIG_auto-login is not set/c CONFIG_auto-login\=y' ${plnxdir}/project-spec/configs/rootfs_config

	# 2.2.4 set rootfs type EXT4
	echo_info "> set rootfs format to EXT4"
	sed -i 's|CONFIG_SUBSYSTEM_ROOTFS_INITRD=y|# CONFIG_SUBSYSTEM_ROOTFS_INITRD is not set|' ${plnxdir}/project-spec/configs/config
	sed -i 's|# CONFIG_SUBSYSTEM_ROOTFS_EXT4 is not set|CONFIG_SUBSYSTEM_ROOTFS_EXT4=y|' ${plnxdir}/project-spec/configs/config
	sed -i '/CONFIG_SUBSYSTEM_INITRD_RAMDISK_LOADADDR=/d' ${plnxdir}/project-spec/configs/config
	echo 'CONFIG_SUBSYSTEM_SDROOT_DEV="/dev/mmcblk0p2"' >> ${plnxdir}/project-spec/configs/config

	# set hostname to xilinx-zcu102-trd
	sed -i '/CONFIG_SUBSYSTEM_HOSTNAME=/c CONFIG_SUBSYSTEM_HOSTNAME\="xilinx-zcu102-trd"' ${plnxdir}/project-spec/configs/config
}

build_proj() {
	cd ${plnxdir}
	petalinux-config -c kernel --silentconfig
	petalinux-config -c rootfs --silentconfig
	petalinux-build
	cd ${plnxdir}/images/linux
	petalinux-package --boot --fsbl zynqmp_fsbl.elf --u-boot u-boot.elf --pmufw pmufw.elf --fpga system.bit --force
	petalinux-package --wic --bootfile "BOOT.BIN boot.scr Image system.dtb" --wic-extra-args "-c gzip"
}

usage() {
	echo "Usage:"
	echo "     ./helper_build_bsp.sh [<xsadir>]"
	echo "     Example: ./helper_build_bsp.sh"
	echo "     Example: ./helper_build_bsp.sh ../hw/prj"
}

main() {
	if [ $# -gt 0 ]; then
		if [ -d "$1" ]; then
			xsadir=$1
		else
			usage; exit
		fi
	fi
	if [ ! -d "$xsadir" ]; then
		echo_error "STOP: xsadir: $xsadir not exit!"; exit 1
	fi
	create_proj
	customize_proj
	build_proj
}

main "$@"
