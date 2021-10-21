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
    image = "linode/ubuntu18.04"
    label = "my_first_cfe_pyapp"
    group = "CFE_Terrafrom_PROJECT"
    region = var.region
    type = "g6-nanode-1"
    authorized_keys = [ var.authorized_key ]
    root_pass = var.root_user_pw
    tags = ["python", "docker", "terraform"]
}
