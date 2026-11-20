# USB webcam mode for the Galaxy S25 Ultra

A KernelSU module that turns a rooted Galaxy S25 Ultra (SM-S938B) into a plug-and-play USB webcam (UVC). Windows, macOS and Linux see it as a normal camera, so no app is needed on the PC.

Android 14 and later include a "use phone as webcam" service (`DeviceAsWebcam`). The S25 has the kernel support for it but ships without the app, and Samsung's framework reports the feature as unsupported. The module adds the app back and works around the parts Samsung switched off.

Tested on an SM-S938B running Android 17 (`CP2A.260605.016`, `S938BXXUCDZIF`), with the app taken from a Galaxy S26 Ultra (SM-S948B) on the same Android build. Result: front camera at 1280×720 and 1920×1080, 30 fps, MJPEG.

## Requirements

- Galaxy S25 Ultra on Android 17, rooted with **KernelSU**. This was tested with a late-loaded KernelSU (`ksud samsung-v2.2`) on a locked bootloader.
- The **[meta-overlayfs](https://github.com/KernelSU-Modules-Repo/meta-overlayfs/releases)** metamodule. KernelSU 2.x no longer mounts module files over `/system` without one.
- `adb` ([Android platform-tools](https://developer.android.com/tools/releases/platform-tools)), only if you build the module yourself.

## Installation

### Quick install (prebuilt)

Download `DeviceAsWebcam_ksu_v1.2.zip` from the [latest release](https://github.com/kotn3l/s25-uvc-webcam/releases/latest) and install it from the KernelSU app (Modules, then Install), **after** meta-overlayfs is installed. Then reboot, root as usual and go to [step 3](#3-use-it).

The release includes the webcam app and its library, taken from a Galaxy S26 Ultra:

| Item | Details |
|---|---|
| Donor phone | Galaxy S26 Ultra (SM-S948B) |
| Donor build | Android 17, `CP2A.260605.016`, `S948BXXU5BZJA` |
| `DeviceAsWebcam.apk` SHA-256 | `0c71eb8e21addf47bcf9cddf5f7cf2856e7dc5132928138ba374faadc0294166` |
| `libjni_deviceAsWebcam.so` SHA-256 | `a32b4a5265ef83f2173bc97fa5dc7379950eac90b91030d100c34bd481828d81` |

The app runs as the system user, so it only works if your phone's firmware is signed with the same Samsung platform key. It was tested on an S25 Ultra on `S938BXXUCDZIF`. If the app doesn't register on your phone, build the module from your own donor as described below.

### Building it yourself

You need a **donor phone** that ships `DeviceAsWebcam` and is signed with the same Samsung platform key as yours, such as a Galaxy S26 Ultra.

### 1. Dump the webcam app from the donor phone

Enable USB debugging on the donor, connect it, then run:

```powershell
adb devices                                   # note the donor's serial
.\scripts\dump_from_donor.ps1 -Serial <donor serial>
```

This copies `DeviceAsWebcam.apk` and `libjni_deviceAsWebcam.so` into `module/system/`.

Before going further, check that the app can run on your phone:

- **Android version:** the donor's SDK (printed by the script) must not be newer than your phone's. Check yours with `adb shell getprop ro.build.version.sdk`. The app's `minSdk` matches the donor's Android version.
- **Signing key:** the app runs as the system user (`android.uid.system`), so it must carry your phone's platform key. Compare the `signatures=[...]` value from these two commands, one on each phone:
  ```
  adb shell dumpsys package android | grep -m1 signatures
  adb shell dumpsys package com.android.DeviceAsWebcam | grep -m1 signatures
  ```

### 2. Build and install the module

```powershell
.\scripts\build_zip.ps1
```

Install `DeviceAsWebcam_ksu.zip` from the KernelSU app (Modules, then Install), **after** meta-overlayfs is installed. Then reboot and root as usual.

### 3. Use it

- After root loads, the module restarts the Android interface once (a soft reboot) so the system picks up the webcam app. See [Why it needs a restart](#2-why-it-needs-a-restart).
- In the KernelSU app, open the **DeviceAsWebcam** module card and tap the **action button** to turn webcam mode on. Tap it again to go back to file transfer.
- On the PC, pick **MJPEG** for 720p or 1080p at 30 fps.

To make the webcam use the front camera, open the webcam preview from its notification and switch cameras there. The module remembers this choice across reboots; see [section 7](#7-camera-choice-resets-after-reboot).

## What was wrong, and how each fix works

### 1. The app is missing

Samsung removed the APK and its JNI library but kept everything else: `ro.usb.uvc.enabled=true`, the `uvc.0` configfs function, the `uvc,adb` USB config in `init.qcom.usb.rc`, and the sysconfig allowlist entries. The module only adds the two files:

```
system/priv-app/DeviceAsWebcam/DeviceAsWebcam.apk
system/lib64/libjni_deviceAsWebcam.so
```

### 2. Why it needs a restart

On a late-loaded KernelSU, root and the overlay mount arrive tens of seconds after the package manager has already scanned `/system/priv-app`, so Android never registers the app (`com.android.DeviceAsWebcam is allowlisted but not present`). `service.sh` runs `setprop ctl.restart zygote` once per boot, which restarts the framework and makes it rescan. A marker in `/dev` stops it from repeating if root is triggered again. If you root at boot (patched boot image), the overlay is mounted early and the script exits without restarting.

### 3. Samsung blocks the automatic start

When USB switches to UVC, the app checks `UsbManager.isUvcSupportEnabled()`. Samsung's `UsbService` answers false (`USB Webcam Support Check = false`), so the app logs `UVC support isn't enabled. Returning early.` and never opens the UVC video device. The Linux UVC gadget stays deactivated until userspace opens that device, so the PC sees nothing. After 3 seconds without a connection, Samsung resets USB to MTP.

`action.sh` gets around this by switching USB to UVC and immediately starting the app's foreground service itself (`DeviceAsWebcamFgServiceImpl`). The service opens the video device, the gadget activates, and the PC sees the camera. If the app is still starting and misses the 3-second window, the script retries once.

### 4. Only 2 fps

`init.qcom.usb.rc` configures the UVC frames as 360p and 720p at `dwFrameInterval 5000000` (2 fps). Only MJPEG 1080p gets 30 fps. `uvc_fps.sh` (run by the action button before webcam mode turns on) unlinks the formats, rewrites the intervals and bitrates, and relinks them:

| Format | Resolution | Frame rates |
|---|---|---|
| MJPEG | 360p, 720p, 1080p | 30 / 15 / 10 |
| YUYV | 360p | 30 / 15 |
| YUYV | 720p | 10 / 5 |

Uncompressed 720p is capped because the phone enumerates at USB 2 high-speed, which can't carry YUYV 720p at 30 fps. The values reset on reboot and are rewritten on the first toggle.

### 5. White picture with a damaged back camera

If the picture is completely white, the camera failed to open and the app is showing its "camera unavailable" placeholder. On the test phone the back camera (ID 0, a logical camera made of several sensors) fails because one sensor's calibration data can't be read, after water damage:

```
CHI: isAvailableModule: Unavailable Cal Data, check i2c or module eeprom
CHI: [HWB] sensorid : [2] have not EEPROM data
CamX: ConfigureStreams() CHI Module failed to configure streams
```

The later `No supported stream configurations with format 0x1` error comes from the placeholder path and is not the cause. Switch to the front camera. On a phone with healthy cameras this should not happen.

### 6. Dropped frames at 30 fps

The camera and the app deliver a steady 30 fps, but parts of frames are lost on the USB link. The webcam stream is isochronous, so the USB controller (dwc3) must be fed every 125 µs. Its interrupt is pinned to CPU 0, which is also busy with the camera, the JPEG encoder and the UI. When the interrupt runs late, the slot is missed (`dwc3_gadget_giveback ... ==> -18`, EXDEV in the kernel trace), the frame arrives incomplete, and the PC drops it.

`usb_irq.sh` (run by the action button) moves the interrupt to CPU 3 and disables that core's deep idle state, which takes 222 µs to wake from. Switching back to file transfer restores both. Measured on the test phone with a kernel trace of `vb2_buf_done` and `dwc3_gadget_giveback`:

| Setup | Frames with lost data |
|---|---|
| Interrupt on CPU 0 (stock) | about 9% |
| Interrupt on CPU 3 | about 2% |
| Interrupt on CPU 3, deep idle off | about 0.6% |

Keeping CPU 3 out of deep idle costs a little battery while webcam mode is on.

### 7. Camera choice resets after reboot

Because the app is missing when Android boots (see [section 2](#2-why-it-needs-a-restart)), the package manager treats it as removed and wipes its data (`System package com.android.DeviceAsWebcam no longer exists; its data will be wiped`). The app then starts with defaults, which means the back camera. On a phone with a damaged back camera, the picture goes white again.

`prefs.sh` keeps a copy of the app's settings as `user.prefs.xml` in the module folder (`/data/adb/modules/deviceaswebcam/`). The action button saves the current settings each time it switches webcam mode off, and also on any later switch-on in the same boot. On the first switch-on after a reboot, it stops the app and puts the saved copy back, with the owner and SELinux label of the app's data folder. The copy is created the first time you switch webcam mode off, so pick your camera, then toggle off and on once.

Reinstalling the module zip deletes the saved copy.

## Troubleshooting

| Symptom | Check |
|---|---|
| Action says the app is not registered | It restarts the framework itself; tap the button again afterwards. |
| PC sees no camera, phone goes back to file transfer | Tap the action button again (first start can be slow). Run `adb logcat \| grep -i DeviceAsWebcam` for errors. |
| Webcam toggle fails when run over adb | Switching USB modes drops adb and kills the shell. Run it detached: `adb shell su -c "setsid nohup /data/adb/ksud module action deviceaswebcam &"` |
| White picture | See [section 5](#5-white-picture-with-a-damaged-back-camera). If it comes back after a reboot, see [section 7](#7-camera-choice-resets-after-reboot). |
| Low frame rate | Pick MJPEG on the PC. Check `cat /config/usb_gadget/g1/functions/uvc.0/streaming/mjpeg/m/720p/dwFrameInterval` shows `333333`. |
| Stutter or dropped frames | Check the USB interrupt moved: `grep dwc3 /proc/interrupts` gives its number, then `cat /proc/irq/<number>/effective_affinity_list` should show `3`. See [section 6](#6-dropped-frames-at-30-fps). |
| Verbose app logs | `adb shell su -c "setprop log.tag.CameraController VERBOSE"`, then restart the app. |

If the phone misbehaves after installing, hold **Volume Down** during boot to start KernelSU in safe mode, which disables all modules.

## Files

```
module/
  module.prop     KernelSU module metadata
  service.sh      one framework restart per boot so the app gets registered
  action.sh       KernelSU action button: toggles webcam mode
  uvc_fps.sh      rewrites UVC frame rates (called by action.sh)
  usb_irq.sh      moves the USB interrupt off CPU 0 (called by action.sh)
  prefs.sh        saves and restores the webcam app's settings (called by action.sh)
  system/         APK and JNI library from the donor (not in git)
scripts/
  dump_from_donor.ps1   pulls the binaries from the donor phone
  build_zip.ps1         builds DeviceAsWebcam_ksu.zip with KernelSU-compatible paths
```

## Notes

- Samsung's software update may break root. You can disable it with `pm disable-user --user 0 com.wssyncmldm` and `pm disable-user --user 0 com.sec.android.soagent` (re-enable with `pm enable`).
## Copyright

The scripts in this repository were written for this project. The binaries in the release (`DeviceAsWebcam.apk` and `libjni_deviceAsWebcam.so`) are not: they were taken unmodified from a Galaxy S26 Ultra's firmware. `DeviceAsWebcam` is based on Android Open Source Project code by Google ([source](https://android.googlesource.com/platform/packages/services/DeviceAsWebcam/)), and these builds were compiled and signed by Samsung. Copyright in them belongs to **Samsung Electronics** and **Google LLC**. They are redistributed only so the module works on phones that lack them. This project is not affiliated with or endorsed by Samsung or Google. If you are a rights holder and want them removed, open an issue.
