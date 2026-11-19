# Board bring-up: BPI-M5 Pro (ArmSoM Sige5)

How to get Flipper OS booting on the Banana Pi BPI-M5 Pro from a Mac.

Status: first bring-up done on 2026-11-19. The board boots Flipper OS from microSD after the factory eMMC boot area was erased (section 4), and Wi-Fi needs a device-tree overlay to stay up (section 8). Sections 5 and 7 have still not been run on hardware.

## 1. Power

The board has two USB-C ports. Only one takes power.

| Port | Silkscreen | Use |
| --- | --- | --- |
| Power | `DCIN` or `PD Only` | Power input only |
| OTG | `TYPEC` | USB data, DisplayPort, MaskROM flashing |

- Input range is 4.5 V to 23 V over USB-C.
- Use a USB-C PD charger of 20 W or more. A laptop, tablet or phone PD charger works; they offer 9 V, 12 V, 15 V or 20 V, all of which are in range.
- ArmSoM also lists 5 V / 3 A as acceptable. A plain 5 V phone charger under 3 A is likely to brown out under load.
- The SoC can pass 60 °C with no cooling. Fit a heatsink or fan before any sustained load.

## 2. Get the image

Flipper builds a full image for this board every night. The target name is `sige5`.

- Listing: <https://dl-linux-images.flipp.dev/full-img/>
- File name: `debian-512-sige5-<build>.img.zst`, with a matching `.bmap`

Build used for the first bring-up:

| File | SHA-256 |
| --- | --- |
| `debian-512-sige5-2494.img.zst` | `4d786608c6621c8591dc3a3328bd5b205ef39da5eda53b027848307bd655a653` |
| `debian-512-sige5-2494.img.bmap` | `49a7c80dcf190d5b0ba9245f15bf624e3bef365178994117809435cb527ae8d5` |

Download and verify:

```bash
mkdir -p images && cd images
curl -fLO https://dl-linux-images.flipp.dev/full-img/2494/debian-512-sige5-2494.img.zst
curl -fLO https://dl-linux-images.flipp.dev/full-img/2494/debian-512-sige5-2494.img.bmap
shasum -a 256 debian-512-sige5-2494.img.*
```

## 3. Boot order

The RK3576 on this board tries storage in a fixed order: eMMC, then microSD, then USB (MaskROM).

If the eMMC ships with a bootloader on it, the board boots that and ignores the microSD card. There are two ways to install, depending on what the eMMC holds.

Our board shipped with ArmSoM's factory Debian 12 (kernel 6.1.57) on a 29 GB eMMC, so it ignored the card. Symptoms with the card in: red LED only, no green heartbeat. With the card out, the green LED blinks and the factory OS boots.

## 4. Option A: microSD card

Needs only the card, a card reader and power. Try this first.

1. Insert the microSD card (8 GB or larger) into the Mac. It will be erased.
2. Open Raspberry Pi Imager.
3. OS: choose "Use custom" and select the `.img.zst` file.
4. Storage: select the microSD card.
5. Write, then eject.
6. Insert the card into the board and connect power.

If the board boots something other than Flipper OS, or nothing appears, the eMMC is taking priority. Either erase the eMMC boot area (below) so the card boots, or use option B.

### Erasing the factory eMMC boot area (what we did)

The factory OS exposes ADB as root over the `TYPEC` port (USB ID `2207:0006`, product `rk3xxx`). With the card out and the factory OS running:

```bash
brew install --cask android-platform-tools
adb devices -l                     # the board should be listed
# Back up the first 16 MiB (partition table, idbloader at sector 64, U-Boot at 8 MiB, misc)
adb exec-out 'dd if=/dev/mmcblk0 bs=1M count=16 2>/dev/null' > sige5-emmc-factory-first16MiB.img
# Erase it; the factory OS can no longer boot, the rest of the eMMC is untouched
adb shell 'dd if=/dev/zero of=/dev/mmcblk0 bs=1M count=16 conv=fsync; sync; poweroff'
```

Check the backup against `adb shell 'dd if=/dev/mmcblk0 bs=1M count=16 | sha256sum'` before erasing. Our backup is in `images/backup/` (git-ignored, SHA-256 `cff3f7516bd3954a623488491bb6eb832bebeaa6fc6db9bc6a7e057518c1838f`). Writing it back to the start of the eMMC restores the factory boot. The `mmcblk0boot0` and `boot1` hardware partitions were empty and did not need touching.

After this, power on with the card in: the green LED starts blinking and Flipper OS boots from the card.

## 5. Option B: write to eMMC over USB (MaskROM)

Needs a USB-C cable from the Mac to the board's OTG port, plus power.

Install `rockusb` on the Mac:

```bash
curl https://sh.rustup.rs -sSf | sh
# reopen the terminal
cargo install --git https://github.com/collabora/rockchiprs.git --example rockusb --features=nusb rockusb
```

Enter MaskROM:

1. Disconnect power.
2. Connect the Mac to the OTG port (`TYPEC`). Do not go through a hub.
3. Hold the MASKROM button and connect power.
4. Run `rockusb list`. A Rockchip device with ID `2207:350e` should appear. Release the button.

Then either run the Flipper OS Installer on the board or write the image directly.

Installer (needs HDMI monitor, USB keyboard and wired network on the board):

```bash
rockusb download-boot installer-falcon-loader.bin
```

Get `installer-falcon-loader.bin` for `sige5` from the installer build artifacts linked in the [install guide](https://docs.flipper.net/one/cpu-software/how-to-install-linux-image).

Direct write (needs the `rk3576_loader_v*.bin` for `sige5`, which comes from a local U-Boot build with the build scripts):

```bash
rockusb download-boot rk3576_loader_v*.bin
rockusb write-bmap debian-512-sige5-2494.img.zst
rockusb reset-device
```

## 6. First boot

Checked on the board on 2026-11-19 (Flipper OS welcome banner: Build ID 1384, profile `@Desktop`, kernel `7.4.0-rc1-g2be532b6a5aa`, Debian 13).

| Item | Value |
| --- | --- |
| User / password | `user` / `user` (in the `sudo` group); confirmed, and the login banner prints it |
| SSH | `openssh-server` running; confirmed |
| Hostname | `armsomsige5-` + first 6 hex of the CPU serial (ours: `armsomsige5-382892`); resolves as `<hostname>.local` |
| USB network | The image starts `usb-ncm-mtp-acm-gadget` (USB ID `37c1:f12e`, interface `flipusb0`, board `10.0.0.1`). Not tested: no cable was in `TYPEC` |
| Wired network | DHCP; confirmed. Our cable was on interface `end1`; `end0` is the other port. Which physical port is which was not checked |
| Wi-Fi | `wlan0`, BCM43752 (Ampak AP6398) on SDIO; needs the overlay in section 8 |

The card holds several boot profiles (Desktop, TV Media Box, Router, Minimal, No Graphics), each with a `7.4.0-rc1` and a vendor `6.1.172` kernel entry under `/boot/loader/entries/`. Desktop on 7.4 boots by default.

Ways in, easiest first:

1. HDMI monitor and USB keyboard.
2. Ethernet: plug into the LAN, then `ssh user@<hostname>.local` or find the address from the router.
3. USB: connect the OTG port to the Mac, then `ssh user@10.0.0.1`.
4. Serial console (below).

Change the default password after the first login.

## 7. Serial console

Useful when the board does not boot far enough for a screen or network. Needs a 3.3 V USB-to-UART adapter that supports 1,500,000 baud (FT232, CP2104 and CH343 do; many CH340 and PL2303 adapters do not).

| Header pin | Signal | Connect to adapter |
| --- | --- | --- |
| 6 | GND | GND |
| 8 | UART0 TX | RX |
| 10 | UART0 RX | TX |

Settings: 1500000 baud, 8 data bits, no parity, 1 stop bit, no flow control. Do not connect the adapter's power pin.

```bash
ls /dev/cu.usb*
minicom -D /dev/cu.usbserial-XXXX -b 1500000
```

The ArmSoM docs do not state the logic level. Confirm it is 3.3 V against the schematic before connecting.

## 8. Wi-Fi: add the v1.2 Wi-Fi/Bluetooth overlay

With the default boot entry, Wi-Fi connects and then freezes, between 97 seconds and about 11 minutes after boot. The kernel logs `brcmfmac: brcmf_sdio_bus_sleep: error while changing bus sleep state -110`, then NetworkManager, `flipctl` and a `brcmf_wq` worker sit in uninterruptible sleep (`D` state). `nmcli` reports "NetworkManager is not running" though systemd says it is active, the load average climbs with no CPU use, and only a reboot clears it. Turning off Wi-Fi power saving (`802-11-wireless.powersave 2`) does not help.

Cause: the plain `rk3576-armsom-sige5.dtb` has no `wifi@1` node under the SDIO controller (`mmc@2a320000`). The chip then runs without its 32 kHz LPO clock (from the `hym8563` RTC) and without its host-wake interrupt, and its bus sleep fails. The image ships an overlay for the v1.2 board, which has this Wi-Fi/Bluetooth module: `rk3576-armsom-sige5-v1.2-wifibt.dtbo`. It adds the `wifi@1` node and enables Bluetooth on `uart4`.

Fix: add the overlay to the boot entry in use, then reboot.

```bash
E=/boot/loader/entries/900-flipperos-Desktop-7.4.0-rc1-g2be532b6a5aa.conf
sudo cp "$E" /root/desktop-7.4-entry.conf.bak
sudo sed -i '/^devicetreedir/a devicetree-overlay /@Desktop/usr/lib/linux-image-7.4.0-rc1-g2be532b6a5aa/rockchip/rk3576-armsom-sige5-v1.2-wifibt.dtbo' "$E"
sudo reboot
```

Other profiles need the same line in their own entry, with their own subvolume (`/@Router/...` and so on). Check the overlay merges cleanly first with `fdtoverlay -i <base>.dtb -o /tmp/test.dtb <overlay>.dtbo`.

After the fix, `ls /proc/device-tree/soc/mmc@2a320000/` lists `wifi@1`, and Bluetooth comes up as `BCM43752A2 ... Ampak AP6398`. On some boots one `bus sleep state -110` error still appears about 6 seconds in, but the chip recovers. Verified 2026-11-19: Wi-Fi stayed connected with no new errors for 17 minutes, past both earlier failure points.

Joining a network so it reconnects at every boot:

```bash
sudo nmcli --ask dev wifi connect "<SSID>"
sudo nmcli con modify "<SSID>" connection.autoconnect yes
```

## Sources

- <https://docs.flipper.net/one/cpu-software/supported-boards>
- <https://docs.flipper.net/one/cpu-software/how-to-install-linux-image>
- <https://github.com/flipperdevices/flipperone-linux-build-scripts>
- <https://docs.armsom.org/armsom-sige5>
- <https://docs.banana-pi.org/en/BPI-M5/BananaPi_BPI-M5_Pro>
