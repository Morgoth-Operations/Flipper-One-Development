# Building a Flipper OS image

How to build the Flipper OS disk image for the BPI-M5 Pro (`sige5`) on a Mac.

Status: the first build completed on 2026-11-17 on an Apple Silicon Mac with Docker Desktop (12 CPUs, 24 GB). It took about an hour from a clean start and produced a 2.3 GB image. The image has not been booted on the board yet.

## How the build works

Flipper's build scripts live in the [build-scripts/](../build-scripts) submodule, which tracks the `dev` branch of [flipperone-linux-build-scripts](https://github.com/flipperdevices/flipperone-linux-build-scripts). That is the branch the nightly images are built from.

The build has four stages, each a script in the submodule:

| Stage | Script | Produces |
| --- | --- | --- |
| Bootloader | `build-uboot.sh` | U-Boot, TF-A and the MaskROM loader for the board |
| Mainline kernel | `build-kernel-mainline.sh` | Kernel packages from `flipper-linux-kernel` |
| BSP kernel | `build-kernel-bsp.sh` | Kernel packages from Rockchip's 6.1 tree |
| Image | `build-images.sh` | Debian root filesystem and the final `.img.zst` |

The scripts expect Debian 13, so they run inside a container built from the submodule's `Dockerfile`.

## One-time setup

1. Install Docker Desktop and start it.
2. In Docker Desktop, open Settings, then Resources, and raise the limits. The image stage alone starts a 10 GB virtual machine.

   | Resource | Suggested |
   | --- | --- |
   | CPUs | 12 |
   | Memory | 24 GB |
   | Disk | 150 GB |

3. Fetch the submodule if the folder is empty:

   ```bash
   git submodule update --init
   ```

## Build

```bash
scripts/build-image.sh
```

The first run builds the container, clones the sources and builds everything. On the Mac above that took about five minutes for the container and an hour for the build. Later runs reuse the container and the cloned sources.

The result is copied to `images/debian-512-sige5-local-<timestamp>.img.zst` with its `.bmap`. Flash it the same way as a nightly image; see [board-bring-up.md](board-bring-up.md).

## Options

Set these as environment variables in front of the command.

| Variable | Default | Effect |
| --- | --- | --- |
| `BOARD` | `sige5` | Board to build the bootloader and image for |
| `KERNELS` | `mainline bsp` | Kernels to build. `mainline` alone is faster; whether the image stage accepts it without the BSP kernel is not yet confirmed |
| `KEEP_SRC` | `yes` | `yes` reuses cloned sources, `update` pulls new commits, `no` clones again |
| `BUILD_ID` | `local-<timestamp>` | Label in the image file name |
| `UPDATE_ROOTFS` | `1` | Rebuild the root filesystem so it contains the kernels just built. Set to empty to reuse the cached one |
| `UPDATE_OSPACK` | unset | Set to `1` to rebuild the Debian package set too |
| `SKIP_CONTAINER_BUILD` | unset | Set to `1` to skip rebuilding the container |

Example, pulling the latest sources and rebuilding everything:

```bash
KEEP_SRC=update UPDATE_OSPACK=1 scripts/build-image.sh
```

## Where things are kept

Sources and intermediate output stay on Docker volumes, not in the repo folder. The kernel tree needs a case-sensitive filesystem, which the Mac's disk is not by default.

| Volume | Holds |
| --- | --- |
| `flipper-build-src` | Cloned U-Boot, TF-A, rkbin and kernel sources |
| `flipper-build-prebuilt` | Staged test tools and the panel UI build |
| `flipper-build-artifacts` | Bootloaders, kernel packages, root filesystem, all images |

To start from nothing:

```bash
docker volume rm flipper-build-src flipper-build-prebuilt flipper-build-artifacts
```

To get the MaskROM loader out, for writing to eMMC over USB:

```bash
docker run --rm -v flipper-build-artifacts:/a -v "$PWD/images:/out" debian:trixie \
    sh -c 'cp /a/u-boot/sige5/rk3576_loader_v*.bin /out/'
```

## Changing the system

- Kernel config: edit the fragments in `build-scripts/configs/linux/`.
- Files in the root filesystem: edit `build-scripts/overlays/`.
- Packages: edit `build-scripts/debian-rk3576-ospack.yaml`, then build with `UPDATE_OSPACK=1`.
- Kernel source: the kernel is cloned inside the `flipper-build-src` volume. To build from a fork, set `LINUX_GIT` and `LINUX_BRANCH`; the wrapper does not pass these through yet.

The submodule points at Flipper's repository, which we cannot push to. Changes made in `build-scripts/` stay local until the submodule is pointed at a fork.

## Publishing a build

Images are published as GitHub Release assets, not committed to git. GitHub limits each asset to 2 GiB, and the build's default compression leaves the image just over that, so recompress it first:

```bash
cd images
mkdir -p release
zstd -dc debian-512-sige5-<id>.img.zst | zstd --ultra -22 -T0 -o release/debian-512-sige5-<id>.img.zst
cp debian-512-sige5-<id>.img.bmap release/
(cd release && shasum -a 256 debian-512-sige5-<id>.img.* > SHA256SUMS)
```

The `.bmap` describes the uncompressed image, so it stays valid. Tag the commit the build came from, push the tag, then create the release from that tag and attach the three files.

## Notes from the first build

- Inside Docker Desktop the image stage has no hardware virtualization, so the scripts fall back to an emulated machine for the root filesystem. That stage took roughly half the build time and used about one CPU core.
- The container builds for the Mac's arm64 architecture with no changes to Flipper's Dockerfile.
- Docker Desktop does not always put `docker` on the PATH. The wrapper falls back to the copy inside the app bundle.
