variable "instance_availability_domain" {
    default = "nvQX:EU-FRANKFURT-1-AD-2"
}

variable "compartment_id" {
    default = "ocid1.tenancy.oc1..aaaaaaaade335wpwo3r2ttc3dit2pmnxs3aqcjuwniqbfyer7jzobufu7muq"
}

variable "instance_shape" {
    default = "VM.Standard.A1.Flex"
}


variable "instance_display_name" {
    default = "k"
}

variable "os_image_id" {
    default = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaao3pblnpkbymhsksku6g4zfvwapxpadwf7hernikcviidle44ghnq"
}

variable "ssh_public_key_file" {
    default = "/root/.ssh/id_rsa.pub"
}

variable "number_of_instances" {
    default = "4"
}

variable "vcn_name" {
    default = "k8s"
}

variable "subnet_name" {
    default = "private"
}

variable "network_load_balancer_display_name"{
    default = "k8s"
}

variable "my_public_ip_address" {
    default = ""
}