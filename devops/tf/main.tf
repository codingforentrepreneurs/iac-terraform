terraform {
    required_version = ">= 0.15"
    required_providers {
        linode = {
            source = "linode/linode"
            version = "1.22.0"
        }
    }
}

provider "linode" {
    token = var.linode_pa_token
}

resource "linode_instance" "cfe-pyapp" {
    count = var.linode_instance_count
    image = "linode/ubuntu18.04"
    label = "pyapp-${count.index + 1}"
    group = "CFE_Terrafrom_PROJECT"
    region = var.region
    type = "g6-nanode-1"
    authorized_keys = [ var.authorized_key ]
    root_pass = var.root_user_pw
    tags = ["python", "docker", "terraform"]
}

resource "local_file" "ansible_inventory" {
    content = join("\n", [for host in linode_instance.cfe-pyapp.*: "${host.ip_address}"])
    filename = "${dirname(abspath(path.root))}/ansible/inventory.ini"
}