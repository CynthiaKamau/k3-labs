variable "name" {
}

data "amazon-ami" "packer_builder" {
  filters = {
    name                = "ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-20200625"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["099720109477"]
  region      = "eu-west-2"
}

locals { timestamp = regex_replace(timestamp(), "[- TZ:]", "") }

source "amazon-ebs" "packer_builder" {
  ami_name      = format("%s-k3s-server-%s", var.name, local.timestamp)
  instance_type = "t3.large"
  region        = "eu-west-2"

  run_tags = {
    owner = "self"
    type  = "k3s-server-packer-builder"
  }

  run_volume_tags = {
    owner = "self"
    type  = "k3s-server-packer-volume"
  }

  source_ami   = data.amazon-ami.packer_builder.id
  ssh_username = "ubuntu"
}

build {
  name    = "k3s-server-ami-builder"
  sources = ["source.amazon-ebs.packer_builder"]

  provisioner "file" {
    destination = "/home/ubuntu/"
    source      = "./provision.sh"
  }

  provisioner "shell" {
    script = "./provision.sh"
  }
}
