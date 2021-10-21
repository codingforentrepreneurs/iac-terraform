output "webapp_first_deploy" {
    value = "${linode_instance.cfe-pyapp.label} : ${linode_instance.cfe-pyapp.ip_address} - ${var.region}"
}