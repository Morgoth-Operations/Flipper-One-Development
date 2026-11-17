# Flipper One Development

Development for Flipper One, done on a Banana Pi BPI-M5 Pro until Flipper One hardware is available.

Flipper One is Flipper Devices' pocket Linux computer built on the Rockchip RK3576. Its operating system, Flipper OS, is Debian-based and built in the open. This repo holds our notes, tooling and changes for running and building Flipper OS on a stand-in board.

## Why this board

The BPI-M5 Pro is the same hardware as the ArmSoM Sige5. Flipper Devices lists it as a supported board for Flipper OS (target name `sige5`) and marks it as recommended for development. It uses the same RK3576 SoC as Flipper One.

| Item | This board |
| --- | --- |
| SoC | Rockchip RK3576 (4x Cortex-A72 + 4x Cortex-A53) |
| GPU / NPU | Mali-G52 MC3 / 6 TOPS |
| RAM | 4 GB LPDDR4 |
| Storage | 64 GB eMMC, microSD slot |
| Flipper OS target | `sige5` |

## Status

| Area | State |
| --- | --- |
| Board bring-up | Steps documented; not yet run on the board |
| Prebuilt image | Nightly build 2494 downloaded and checksum-verified |
| Local image build | Working: first `sige5` image built on 2026-11-17; not yet booted |

## Getting started

Clone with the submodule:

```bash
git clone --recurse-submodules git@github.com:Morgoth-Operations/Flipper-One-Development.git
```

If you already cloned without it:

```bash
git submodule update --init
```

Then follow the guides in order:

1. [docs/board-bring-up.md](docs/board-bring-up.md): power the board, flash Flipper OS, and get a console.
2. [docs/image-building.md](docs/image-building.md): build the Flipper OS image locally with Docker.

To build an image for the board once Docker Desktop is running:

```bash
scripts/build-image.sh
```

## Layout

| Path | Contents |
| --- | --- |
| [docs/](docs) | Bring-up and build guides |
| [scripts/build-image.sh](scripts/build-image.sh) | One-command image build in a container |
| [build-scripts/](build-scripts) | Flipper's build scripts, as a submodule on their `dev` branch |
| `images/` | Downloaded and built OS images and build logs; not tracked in git |

## Upstream references

- [Flipper One CPU software docs](https://docs.flipper.net/one/cpu-software/about)
- [Supported boards](https://docs.flipper.net/one/cpu-software/supported-boards)
- [flipperone-linux-build-scripts](https://github.com/flipperdevices/flipperone-linux-build-scripts)
- [flipper-linux-kernel](https://github.com/flipperdevices/flipper-linux-kernel)
- [Prebuilt images](https://dl-linux-images.flipp.dev/full-img/)
- [Banana Pi BPI-M5 Pro docs](https://docs.banana-pi.org/en/BPI-M5/BananaPi_BPI-M5_Pro)
- [ArmSoM Sige5 docs](https://docs.armsom.org/armsom-sige5)
