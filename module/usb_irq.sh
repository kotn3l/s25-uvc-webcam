#!/system/bin/sh
# usb_irq.sh on|off
# The USB controller (dwc3) interrupt is pinned to CPU 0, which is busy with the
# camera, the JPEG encoder and the UI. Isochronous slots are 125 us apart, so a
# late interrupt loses part of a frame and the PC drops it. "on" moves the
# interrupt to a quieter core and keeps that core out of deep idle (wake-up
# latency 222 us); "off" restores both.
CPU=3
SAVE=/dev/.deviceaswebcam_irq

IRQ=$(grep -m1 -E '[[:space:]]dwc3$' /proc/interrupts | cut -d: -f1 | tr -d ' ')
[ -n "$IRQ" ] || { echo "! dwc3 interrupt not found"; exit 0; }

case "$1" in
    on)
        [ -e "$SAVE" ] || cat /proc/irq/$IRQ/smp_affinity_list > "$SAVE"
        echo $CPU > /proc/irq/$IRQ/smp_affinity_list
        for s in /sys/devices/system/cpu/cpu$CPU/cpuidle/state*; do
            [ "${s##*state}" = 0 ] || echo 1 > $s/disable
        done
        echo "- USB interrupt $IRQ moved to CPU $CPU"
        ;;
    off)
        [ -e "$SAVE" ] && cat "$SAVE" > /proc/irq/$IRQ/smp_affinity_list && rm -f "$SAVE"
        for s in /sys/devices/system/cpu/cpu$CPU/cpuidle/state*; do
            echo 0 > $s/disable
        done
        ;;
esac
