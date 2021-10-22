terraform {
    required_version = ">= 0.15"
    required_providers {
        linode = {
            source = "linode/linode"
            version = "1.22.0"
        }
    }
    backend "s3" {
        skip_credentials_validation = true
        skip_region_validation = true
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

     provisioner "file" {
        connection {
            host = "${self.ip_address}"
            type = "ssh"
            user = "root"
            password = "${var.root_user_pw}"
        }
        source = "${local.project_dir}/bootstrap-docker.sh"
        destination = "/tmp/bootstrap-docker.sh"
    }

    provisioner "remote-exec" {
        connection {
            host = "${self.ip_address}"
            type = "ssh"
            user = "root"
            password = "${var.root_user_pw}"
        }
        inline = [
            "chmod +x /tmp/bootstrap-docker.sh",
            "sudo sh /tmp/bootstrap-docker.sh",
            "mkdir -p /var/www/src/",
        ]
    }

     provisioner "file" {
        connection {
            host = "${self.ip_address}"
            type = "ssh"
            user = "root"
            password = "${var.root_user_pw}"
        }
        source = "${local.project_dir}/src/"
        destination = "/var/www/src/"
    }

    provisioner "file" {
        connection {
            host = "${self.ip_address}"
            type = "ssh"
            user = "root"
            password = "${var.root_user_pw}"
        }
        source = "${local.project_dir}/Dockerfile"
        destination = "/var/www/Dockerfile"
    }

    provisioner "file" {
        connection {
            host = "${self.ip_address}"
            type = "ssh"
            user = "root"
            password = "${var.root_user_pw}"
        }
        source = "${local.project_dir}/entrypoint.sh"
        destination = "/var/www/entrypoint.sh"
    }

    provisioner "file" {
        connection {
            host = "${self.ip_address}"
            type = "ssh"
            user = "root"
            password = "${var.root_user_pw}"
        }
        source = "${local.project_dir}/requirements.txt"
        destination = "/var/www/requirements.txt"
    }


    provisioner "remote-exec" {
        connection {
            host = "${self.ip_address}"
            type = "ssh"
            user = "root"
            password = "${var.root_user_pw}"
        }
        inline = [
            "cd /var/www/",
            "docker build -f Dockerfile -t pyapp-via-git . ",
            "docker run --restart always -p 80:8001 -e PORT=8001 -d pyapp-via-git"
        ]
    }

   
    
}

resource "local_file" "ansible_inventory" {
    # content = join("\n", [for host in linode_instance.cfe-pyapp.*: "${host.ip_address}"])
    content = templatefile("${local.templates_dir}/ansible-inventory.tpl", { hosts=[for host in linode_instance.cfe-pyapp.*: "${host.ip_address}"] })
    filename = "${local.devops_dir}/ansible/inventory.ini"
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