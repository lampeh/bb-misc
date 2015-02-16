1. copy pru-foo-01-00A0.dtbo to /lib/firmware
2. edit /boot/uboot/uEnv.txt and set cape_disable=capemgr.disable_partno=BB-BONELT-HDMI,BB-BONELT-HDMIN
3. reboot
4. echo pru-foo-01 >/sys/devices/bone_capemgr.9/slots
5. run PRU code
