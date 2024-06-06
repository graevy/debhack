packer {
    required_plugins {
        qemu = {
            version = ">= 1.1.0"
            source = "github.com/hashicorp/qemu"
        }
    }
    required_version = ">= 1.7.0, < 2.0.0"
}

variable "debian_version" {
  default = "12.5.0"
}

variable "iso_url" {
  default = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.5.0-amd64-netinst.iso"
}

variable "iso_checksum" {
  # get debian's SHA from https://cdimage.debian.org/cdimage/release/12.5.0/amd64/iso-cd/SHA256SUMS
  # there's a packer syntax i haven't explored yet:
  # default = "file:https://cdimage.debian.org/cdimage/release/12.5.0/amd64/iso-cd/SHA256SUMS"
  default = "sha256:013f5b44670d81280b5b1bc02455842b250df2f0c6763398feb69af1a805a14f"
}

# https://developer.hashicorp.com/packer/integrations/hashicorp/qemu/latest/components/builder/qemu
source "qemu" "debian" {
  iso_url            = var.iso_url
  iso_checksum       = var.iso_checksum
  output_directory   = "output/debian-12.5.0"
  vm_name            = "debbie"
  memory             = 2048
  disk_size          = 4096
  format             = "qcow2"
  headless           = true
  # might need to set up the net_device/net_bridge option
  http_directory     = "http"
  boot_command       = [
    "<esc><wait>",
    "install ",
    "auto ",
    "url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg ",
    "debian-installer=en_US ",
    "locale=en_US ",
    "kbd-chooser/method=us ",
    "hostname={{user `hostname`}} ",
    "preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg ",
    "<enter>"
  ]
  ssh_username       = "packer"
  ssh_password       = "packer"
  ssh_wait_timeout   = "20m"
}

build {
  sources = ["source.qemu.debian"]

  provisioner "shell" {
    inline = [
      "apt update",
      "apt upgrade -y"
    ]
  }
}
