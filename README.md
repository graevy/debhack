this script automates a "normal" debian netinst image using a provided `preseed.cfg`. it repacks the read-only image with the preseed to generate a new image. read more about this [here](https://wiki.debian.org/ManipulatingISOs#remaster). it also edits some of the files in the image to use this preseed.

it's simpler than tools like ansible or FAI for the purpose of putting debian on small amounts of headless bare metal, though it assumes things about the filesystem of the debian image. i use this to image servers at a [hackerspace](https://devhack.net) before applying terraform configs in lieu of dealing with a PXE on donated hardware.

obviously, be careful about burning this to a usb and booting off of it, because it will just pave over the first drive the debian installer finds, and it looks like a normal debian installer. put a warning on the thumb drive.

usage:

`sudo ./repack_mbr.sh /path/to/debian/iso`

- xorriso dependency
- the debian image must be MBR. most are; there are GPT ones
- only tested on netinst isos
