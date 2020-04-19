# ulx3s_bbc_micro

![BBC Micro](https://upload.wikimedia.org/wikipedia/commons/3/32/BBC_Micro_Front_Restored.jpg)

Version of [Ice40Beeb](https://github.com/hoglet67/Ice40Beeb) for Ulx3s ECP5 board

Thanks to [David Banks](https://github.com/hoglet67) for the Ice40 version

To build and upload the bit file do:

```sh
cd ulx3s
make prog
```

The rom is read from flash memory at address 0x80000.

To create the rom do;

```sh
cd roms
./build.sh
```

The rom you need is then in roms/boot_c000_f17fff/beeb_roms.bin.


You should then copy that to flash memory, e.g by ftp to the esp32:

```sh
put beeb_roms.bin flash@0x80000
```

You can download the [BEEB.MMC software archive](https://github.com/hoglet67/Ice40Beeb/releases/download/release_1/BEEB.MMB.zip).

It needs to be unzipped to the root directory of a Fat32 SD card.

Using a PS/2 keyboard connected to us2, do Shift+Print Screen to start the software archive on the SD card.

VGA output is via a Digilent VGA Pmod. HDMI output is not yet supported.

The default build is for the 85f. For other boards use the DEVICE parameter to the make ile, e.g. `make DEVICE=12k`.
