# vidncnn

A video enhancement tool using ncnn.

## videnh

Use AI to enhance videos. Enhances the quality of the video with Real-ESRGAN, doubles the frame rate with RIFE interpolation and allows for custom output frame size, among other things. It uses ncnn Vulkan implementations of Real-ESRGAN and RIFE to be more platform independent. 

**Requirements:**

curl ffmpeg imagemagick rsync unzip util-linux wget
[Real-ESRGAN ncnn Vulkan](https://github.com/xinntao/Real-ESRGAN/),
[RIFE ncnn Vulkan](https://github.com/nihui/rife-ncnn-vulkan)

### Install:

Run the `install.sh` as superuser. If you don't have the APT package mager on your system, you first need to install the above packages excluding the ncnn implementations linked. The install script will download and install the ncnn Vulkan implementations of Real-ESRGAN and RIFE as well as the `videnh` script automatically to `/user/local/`.

### Usage:
```
Usage: videnh [OPTIONS] FILE

Options:
  -f --fps        Number of frames per second in the output video
                  Default: same as input or double if RIFE is used
  -m --model      ESRGAN model: realesrgan-x4plus, RealESRGAN_General_x4_v3 ... 
                  Default: RealESRGAN_General_WDN_x4_v3
  -n --noesrgan   Skip ESRGAN step.
  -l --lighten    Opacity of the lighten layer in percent, e.g.: 75% 
                  Default: n
  -s --size       Resolution of the output image: [W]x[H][!]
                  Default: 4x the original video
  -q --quality    Quality of the H.264 output video: CRF 0-51
                  Default: 10
  -r --rife       Apply RIFE interpolation in order to double the frame rate.
  -x --tta        Enable tta mode
  -h --help
```

### TODO:

- Include source audio in output.
- Let the user choose install path.
- Fix lighten when Real-ESRGAN is not used. (Pointless really.)
