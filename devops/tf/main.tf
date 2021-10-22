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
    private_ip = true
    tags = ["python", "docker", "terraform"]

    provisioner "remote-exec" {
        connection {
            host = "${self.ip_address}"
            type = "ssh"
            user = "root"
            password = "${var.root_user_pw}"
        }
        inline = [
            "sudo apt-get update",
            "sudo apt-get install nginx -y"
        ]
    }

    provisioner "file" {
        connection {
            host = "${self.ip_address}"
            type = "ssh"
            user = "root"
            password = "${var.root_user_pw}"
        }
        content = "<h1>${self.ip_address}</h1>"
        destination = "/var/www/html/index.nginx-debian.html"
    }
    
}

resource "local_file" "ansible_inventory" {
    # content = join("\n", [for host in linode_instance.cfe-pyapp.*: "${host.ip_address}"])
    content = templatefile("${abspath(path.root)}/templates/ansible-inventory.tpl", { hosts=[for host in linode_instance.cfe-pyapp.*: "${host.ip_address}"] })
    filename = "${dirname(abspath(path.root))}/ansible/inventory.ini"
}

resource "linode_nodebalancer" "pycfe_nb" {
    label = "pycfe-nodebalancer"
    region = var.region
    client_conn_throttle = 20
    depends_on = [
        linode_instance.cfe-pyapp
    ]
}

resource "linode_nodebalancer_config" "pycfe_nb_config" {
    nodebalancer_id = linode_nodebalancer.pycfe_nb.id
    port = 80
    protocol = "http"
    check = "http"
    check_path = "/"
    check_interval = 35
    check_attempts = 15
    check_timeout = 30
    stickiness = "http_cookie"
    algorithm = "source"
}

resource "linode_nodebalancer_node" "pycfe_nb_node" {
    count = var.linode_instance_count
    nodebalancer_id = linode_nodebalancer.pycfe_nb.id
    config_id = linode_nodebalancer_config.pycfe_nb_config.id
    label = "pycfe_node_pyapp_${count.index + 1}"
    address = "${element(linode_instance.cfe-pyapp.*.private_ip_address, count.index)}:80"
    weight = 50
    mode = "accept"
}