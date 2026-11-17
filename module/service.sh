#!/system/bin/sh
# Root is loaded after PackageManager has scanned /system, so the overlaid
# DeviceAsWebcam app is missed. Restart the framework once per boot to pick it up.
MARK=/dev/.deviceaswebcam_restarted
[ -e "$MARK" ] && exit 0

until [ "$(/system/bin/getprop sys.boot_completed)" = "1" ]; do sleep 1; done
for i in $(seq 1 30); do
    [ -f /system/priv-app/DeviceAsWebcam/DeviceAsWebcam.apk ] && break
    sleep 1
done
touch "$MARK"

/system/bin/pm path com.android.DeviceAsWebcam >/dev/null 2>&1 && exit 0
/system/bin/setprop ctl.restart zygote
