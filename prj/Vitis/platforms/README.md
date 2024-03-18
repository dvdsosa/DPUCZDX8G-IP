# Vitis Embedded Platform Source Repository

Welcome to the Vitis embedded platform source repository. This repository is based on [Vitis Embedded
Platforms][3]. The `differences` are shown as following:

[3]: https://github.com/Xilinx/Vitis_Embedded_Platform_Source

- Build these platforms with post-impl xsa and petalinux as default
- The hw part stays the same as Vitis Embedded Platforms
- The sw/prebuilt_linux folder has been removed
- Add sw/petalinux
- The sw/petalinux part pre-installs recipes for Vitis AI Runtime and Library v3.0.0
- The sw/petalinux part pre-installs recipes for [app/dpu_sw_optimize.tar.gz](../../../app/dpu_sw_optimize.tar.gz)
- The sw/petalinux part supports the saving of uboot environment variables on uboot command line
- The sw/petalinux enables auto-login with root for devlopment mode, which is not recommended in your own production
- When building PetaLinux image from source code, the build temp directory is set to **${PROOT}/build/tmp/**. You can update the build temp directory by modifying CONFIG_TMP_DIR_LOCATION option in **<platform_name>/sw/petalinux/project-spec/configs/config** file



## Build Instructions


This package comes with sources to generate the Vitis platform with three stages:

- Generate hardware specification file (XSA) using Vivado.
- Generate software components of platform (using either Petalinux or XSCT).
- Generate the Vitis platform by packaging hardware and software together using XSCT tool

Vitis and PetaLinux environment need to be setup before building the platform.

  ```bash
  source <Vitis_v2022.2_install_path>/Vitis/2022.2/settings64.sh
  source <PetaLinux_v2022.2_install_path>/settings.sh
  ```

Build platform with xsa and build all sw/petalinux components(not use pre-built petalinux). Users can customise software components to have additional libraries, packages etc

  ```bash
  make all
  # Platform will be built with post-imple xsa and all sw/petalinux components

  make all PRE_SYNTH=TRUE
  # Platform will be built with pre-synth xsa and all sw/petalinux components
  ```

After the build process completes, the built platform output is located at `platform_repo/<platform_name>/export/<platform_name>/` directory, which can be used in `DPU TRD Vitis Flow`.


[DPU TRD Vitis Flow ](../README.md)



`NOTE`:

1.The platform hardware has two types.

- **Pre-Synth XSA** : Hardware specification file (XSA) in the platform does not contain bitstream. The XSA build time is quicker than Post-Impl XSA.
- **Post-Impl XSA** : XSA in this flow contains PL bitstream in it and generation time will be longer. By default, Vitis platform Makefile generates post-impl platforms.

2.The DPU requires continuous physical memory, which can be implemented by CMA. `In platform source, the CMA is set to 1536M for zcu102 and zcu104 as default`. There are two ways to modify CMA if needed
- Modify CONFIG_SUBSYSTEM_USER_CMDLINE option in **<platform_name>/sw/petalinux/project-spec/configs/config** file
- Modify by saving uboot environment on uboot command line. `For example`:
  ```bash
  ZynqMP> setenv bootargs "earlycon console=ttyPS0,115200 clk_ignore_unused root=/dev/mmcblk0p2 rw rootwait cma=512M"
  ZynqMP> saveenv
  Saving Environment to FAT... OK
  ZynqMP> reset
  resetting ..
  ```
  Check CMA when kernel starts up
  ```
  [    0.000000] cma: Reserved 512 MiB at 0x000000005fc00000
  ```


## Third-Party Content
All Xilinx and third-party licenses and sources associated with this reference design can be downloaded [here](https://www.xilinx.com/member/forms/download/xef.html?filename=xilinx-zynqmp-common-target-2022.2.tar.gz).


## License
Licensed under the Apache License, version 2.0 (the "License"); you may not use this file except in compliance with the License.

You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

<p align="center"><sup>Copyright&copy; 2022 Xilinx</sup></p>
