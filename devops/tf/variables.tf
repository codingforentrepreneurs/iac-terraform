variable "linode_pa_token" {
    sensitive = true
}

variable "authorized_key" {
    sensitive = true
}

variable "root_user_pw" {
    sensitive = true
}

variable "region" {
    default = "us-east"
}