#!/system/bin/sh
# Qualcomm's init.qcom.usb.rc limits 360p/720p to 2 fps. Rewrite the UVC frame
# intervals while uvc.0 is not part of the active USB config.
U=/config/usb_gadget/g1/functions/uvc.0
S=$U/streaming

[ -d "$S/mjpeg/m/720p" ] || { echo "! UVC function not set up"; exit 1; }
grep -q 333333 "$S/mjpeg/m/720p/dwFrameInterval" && exit 0
ls -l /config/usb_gadget/g1/configs/b.1/ | grep -q uvc.0 && {
    echo "! UVC is active, switch to file transfer first"; exit 1; }

# frame dir, width, height, fps list (fastest first)
set_frame() {
    F=$1; W=$2; H=$3; shift 3
    I=""; for fps in "$@"; do I="$I$((10000000 / fps))
"; done
    echo -n "$I" > "$F/dwFrameInterval"
    echo $((10000000 / $1)) > "$F/dwDefaultFrameInterval"
    echo $((W * H * 16 * $1)) > "$F/dwMaxBitRate"
    eval "last=\${$#}"
    echo $((W * H * 16 * last)) > "$F/dwMinBitRate"
    echo $((W * H * 2)) > "$F/dwMaxVideoFrameBufferSize"
}

rm "$S/class/fs/h" "$S/class/hs/h" "$S/class/ss/h"
rm "$S/header/h/u" "$S/header/h/m"

set_frame "$S/mjpeg/m/360p" 640 360 30 15 10
set_frame "$S/mjpeg/m/720p" 1280 720 30 15 10
set_frame "$S/mjpeg/m/1080p" 1920 1080 30 15 10
set_frame "$S/uncompressed/u/360p" 640 360 30 15
set_frame "$S/uncompressed/u/720p" 1280 720 10 5
RC=$?

ln -s "$S/uncompressed/u" "$S/header/h/u"
ln -s "$S/mjpeg/m" "$S/header/h/m"
ln -s "$S/header/h" "$S/class/fs/h"
ln -s "$S/header/h" "$S/class/hs/h"
ln -s "$S/header/h" "$S/class/ss/h"
echo "- UVC frame rates updated"
exit $RC
