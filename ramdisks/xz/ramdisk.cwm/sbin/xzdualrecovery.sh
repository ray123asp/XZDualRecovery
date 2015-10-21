#!/sbin/busybox sh

# Backup original LD_LIBRARY_PATH value to restore it later.
_LDLIBPATH="$LD_LIBRARY_PATH"
# Backup original PATH value to restore later
_PATH="$PATH"

export LD_LIBRARY_PATH=".:/sbin:/system/vendor/lib:/system/lib"
export PATH="/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin"

#https://github.com/android/platform_system_core/commit/e18c0d508a6d8b4376c6f0b8c22600e5aca37f69
#The busybox in all of the recoveries has not yet been patched to take this in account.
/sbin/busybox blockdev --setrw $(/sbin/find /dev/block/platform/msm_sdcc.1/by-name/ -iname "system")

# Making darn sure sysfs has been mounted, otherwise the LED control will fail.
if [ "$(/sbin/busybox cat /proc/mounts | /sbin/busybox grep 'sysfs' | /sbin/busybox grep '/sys' | /sbin/busybox wc -l)" = "0" ]; then
	/sbin/busybox mount -t sysfs sysfs /sys
fi

REDLED=$(/sbin/busybox ls -1 /sys/class/leds | /sbin/busybox grep "red\|LED1_R")
GREENLED=$(/sbin/busybox ls -1 /sys/class/leds | /sbin/busybox grep "green\|LED1_G")
BLUELED=$(/sbin/busybox ls -1 /sys/class/leds | /sbin/busybox grep "blue\|LED1_B")

SETLED() {
        BRIGHTNESS_LED_RED="/sys/class/leds/$REDLED/brightness"
        CURRENT_LED_RED="/sys/class/leds/$REDLED/led_current"
        BRIGHTNESS_LED_GREEN="/sys/class/leds/$GREENLED/brightness"
        CURRENT_LED_GREEN="/sys/class/leds/$GREENLED/led_current"
        BRIGHTNESS_LED_BLUE="/sys/class/leds/$BLUELED/brightness"
        CURRENT_LED_BLUE="/sys/class/leds/$BLUELED/led_current"

        if [ "$1" = "on" ]; then

                echo "$2" > ${BRIGHTNESS_LED_RED}
                echo "$3" > ${BRIGHTNESS_LED_GREEN}
                echo "$4" > ${BRIGHTNESS_LED_BLUE}

                if [ -f "$CURRENT_LED_RED" -a -f "$CURRENT_LED_GREEN" -a -f "$CURRENT_LED_BLUE" ]; then

                        echo "$2" > ${CURRENT_LED_RED}
                        echo "$3" > ${CURRENT_LED_GREEN}
                        echo "$4" > ${CURRENT_LED_BLUE}
                fi

        else

                echo "0" > ${BRIGHTNESS_LED_RED}
                echo "0" > ${BRIGHTNESS_LED_GREEN}
                echo "0" > ${BRIGHTNESS_LED_BLUE}

                if [ -f "$CURRENT_LED_RED" -a -f "$CURRENT_LED_GREEN" -a -f "$CURRENT_LED_BLUE" ]; then

                        echo "0" > ${CURRENT_LED_RED}
                        echo "0" > ${CURRENT_LED_GREEN}
                        echo "0" > ${CURRENT_LED_BLUE}
                fi

        fi
}

FLASHLED() {
	SETLED on 255 0 0
	sleep 1
	SETLED off
	sleep 1
	FLASHLED
}

for LOCKINGPID in `/sbin/busybox lsof | awk '{print $1" "$2}' | grep -E "/bin|/system|/data|/cache" | awk '{print $1}'`; do
	BINARY=$(ps | grep " $LOCKINGPID " | grep -v "grep" | awk '{print $5}')
        echo "File ${BINARY} is locking a critical partition running as PID ${LOCKINGPID}, killing it now!" >> /tmp/xperiablfix.log
	kill -9 $LOCKINGPID
done

REMAINING=$(/sbin/busybox lsof | awk '{print $1" "$2}' | grep -E "/bin|/system|/data|/cache" | wc -l)
if [ $REMAINING -gt 0 ]; then
	FLASHLED
fi

echo "Anti-Filesystem-Lock completed." >> /tmp/xzdr.log

# Returning values to their original settings
export LD_LIBRARY_PATH="$_LDLIBPATH"
export PATH="$_PATH"

exit 0
