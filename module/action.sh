#!/system/bin/sh
# Toggle USB webcam mode. Samsung reports UVC as unsupported, so the app's
# USB_STATE receiver bails; start its foreground service directly instead.
MODDIR=${0%/*}
FGS=com.android.DeviceAsWebcam/com.android.deviceaswebcam.DeviceAsWebcamFgServiceImpl

if ! /system/bin/pm path com.android.DeviceAsWebcam >/dev/null 2>&1; then
    echo "! Webcam app is not registered yet."
    echo "! Restarting the framework; run this action again afterwards."
    touch /dev/.deviceaswebcam_restarted
    /system/bin/setprop ctl.restart zygote
    exit 0
fi

start_webcam() {
    /system/bin/svc usb setFunctions uvc
    sleep 0.3
    /system/bin/am start-foreground-service -n "$FGS" >/dev/null
    sleep 4
    case "$(/system/bin/getprop sys.usb.config)" in *uvc*) return 0 ;; esac
    return 1
}

case "$(/system/bin/getprop sys.usb.config)" in
    *uvc*)
        echo "- Webcam mode is on, switching back to file transfer"
        sh "$MODDIR/prefs.sh" save
        /system/bin/am stopservice -n "$FGS" >/dev/null 2>&1
        /system/bin/svc usb setFunctions mtp
        sh "$MODDIR/usb_irq.sh" off
        echo "- Done"
        ;;
    *)
        sh "$MODDIR/prefs.sh" save
        sh "$MODDIR/prefs.sh" restore
        sh "$MODDIR/uvc_fps.sh"
        sh "$MODDIR/usb_irq.sh" on
        echo "- Switching USB to webcam mode"
        if start_webcam || { echo "- Retrying (webcam app was starting up)"; start_webcam; }; then
            echo "- Done. The PC should now see a USB camera."
        else
            echo "! Webcam mode did not stick, try again"
        fi
        ;;
esac
