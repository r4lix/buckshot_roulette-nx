#!/bin/bash
# nxvk change used by Buckshot Roulette NX: swapchains of 3..5 images (the requested count, clamped) instead of a fixed
# count, so the frame-generation hook can ask for one image more than Zink does. Then build the GL (Zink) package.
#
# Run inside the nxvk build container with the nxvk tree at /work and an output folder at /out, e.g.
#   docker run --rm -v nxvk-work:/work -v "<pkg dir>:/out" nxvk:latest bash /out/wsi_swapchain_images.sh
# Afterwards make the hooked archive the Godot build links (see godot/platform/switch/detect.py):
#   aarch64-none-elf-objcopy --redefine-sym vk_icdGetInstanceProcAddr=nx_hook_GetInstanceProcAddr \
#       --redefine-sym vk_common_GetDeviceProcAddr=nx_hook_GetDeviceProcAddr lib/libnvk_gl.a lib/libnvk_gl_hooked.a
set -e
cd /work
f=src/vulkan/wsi/wsi_switch.c
sed -i 's/#define WSI_SWITCH_IMAGE_COUNT 4/#define WSI_SWITCH_IMAGE_COUNT 3/' $f
grep -q WSI_SWITCH_MAX_IMAGES $f || sed -i 's/#define WSI_SWITCH_IMAGE_COUNT 3/#define WSI_SWITCH_IMAGE_COUNT 3\n#define WSI_SWITCH_MAX_IMAGES 5/' $f
sed -i 's/#define WSI_SWITCH_MAX_IMAGES 4/#define WSI_SWITCH_MAX_IMAGES 5/' $f
sed -i 's/caps->maxImageCount = WSI_SWITCH_IMAGE_COUNT;/caps->maxImageCount = WSI_SWITCH_MAX_IMAGES;/' $f
sed -i 's/   const uint32_t num_images = WSI_SWITCH_IMAGE_COUNT;/   const uint32_t num_images = MIN2(MAX2(pCreateInfo->minImageCount, WSI_SWITCH_IMAGE_COUNT), WSI_SWITCH_MAX_IMAGES);/' $f
sed -i 's/   const uint32_t num_images = pCreateInfo->minImageCount > WSI_SWITCH_IMAGE_COUNT ? WSI_SWITCH_MAX_IMAGES : WSI_SWITCH_IMAGE_COUNT;/   const uint32_t num_images = MIN2(MAX2(pCreateInfo->minImageCount, WSI_SWITCH_IMAGE_COUNT), WSI_SWITCH_MAX_IMAGES);/' $f
grep -n 'WSI_SWITCH_IMAGE_COUNT\|WSI_SWITCH_MAX_IMAGES\|const uint32_t num_images' $f
CONTAINER= make gl 2>&1 | tail -3
mkdir -p /out/lib
cp -r switch/build/pkg/lib/. /out/lib/
ls -la /out/lib
