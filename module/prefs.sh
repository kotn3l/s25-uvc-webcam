#!/system/bin/sh
# prefs.sh save|restore
# Android wipes the webcam app's data at every boot because the app is missing
# until root mounts it, so the camera choice (front/back) and quality setting
# are lost. Keep a copy in the module folder and put it back once per boot.
MODDIR=${0%/*}
PKG=com.android.DeviceAsWebcam
DATA=/data/data/$PKG
DIR=$DATA/shared_prefs
FILE=$DIR/$PKG.user.prefs.xml
SAVED=$MODDIR/user.prefs.xml
MARK=/dev/.deviceaswebcam_prefs_restored

case "$1" in
    save)
        # Before the first restore of this boot the app holds defaults, not the user's choice
        [ -e "$MARK" ] && [ -f "$FILE" ] && cp "$FILE" "$SAVED"
        ;;
    restore)
        [ -e "$MARK" ] && exit 0
        touch "$MARK"
        [ -f "$SAVED" ] && [ -d "$DATA" ] || exit 0
        cmp -s "$SAVED" "$FILE" && exit 0
        # The app caches its prefs in memory, so stop it before replacing the file
        /system/bin/am force-stop $PKG
        CTX=$(ls -Zd "$DATA" | cut -d' ' -f1)
        if [ ! -d "$DIR" ]; then
            mkdir "$DIR"
            chown system:system "$DIR"
            chmod 771 "$DIR"
            chcon "$CTX" "$DIR"
        fi
        cp "$SAVED" "$FILE"
        chown system:system "$FILE"
        chmod 660 "$FILE"
        chcon "$CTX" "$FILE"
        echo "- Restored webcam app settings"
        ;;
esac
