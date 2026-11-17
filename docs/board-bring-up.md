# Board bring-up: BPI-M5 Pro (ArmSoM Sige5)

How to get Flipper OS booting on the Banana Pi BPI-M5 Pro from a Mac.

Status: written from the vendor and Flipper documentation on 2026-11-17. Nothing here has been run on the board yet. Steps marked "to confirm" are the ones most likely to need correcting after the first boot.

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

## 4. Option A: microSD card

Needs only the card, a card reader and power. Try this first.

1. Insert the microSD card (8 GB or larger) into the Mac. It will be erased.
2. Open Raspberry Pi Imager.
3. OS: choose "Use custom" and select the `.img.zst` file.
4. Storage: select the microSD card.
5. Write, then eject.
6. Insert the card into the board and connect power.

If the board boots something other than Flipper OS, or nothing appears, the eMMC is taking priority. Use option B.

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

Defaults read from the Flipper build scripts. To confirm on the board.

| Item | Value |
| --- | --- |
| User / password | `user` / `user` (in the `sudo` group) |
| SSH | `openssh-server` is installed; host keys are generated on first boot |
| Hostname | `<board>-<first 6 hex of serial>`, expected `armsomsige5-xxxxxx` |
| USB network | The OTG port presents a USB Ethernet device; the board is `10.0.0.1` |
| Wired network | DHCP on the Ethernet port |

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

## Sources

- <https://docs.flipper.net/one/cpu-software/supported-boards>
- <https://docs.flipper.net/one/cpu-software/how-to-install-linux-image>
- <https://github.com/flipperdevices/flipperone-linux-build-scripts>
- <https://docs.armsom.org/armsom-sige5>
- <https://docs.banana-pi.org/en/BPI-M5/BananaPi_BPI-M5_Pro>
