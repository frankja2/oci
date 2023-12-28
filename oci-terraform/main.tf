terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
      version = "5.23.0"
    }
  }
}

provider "oci" {
    user_ocid        = 
    fingerprint      = 
    tenancy_ocid     = 
    region           = 
    private_key_path = 
}

module "vcn" {
  source  = "oracle-terraform-modules/vcn/oci"
  version = "3.6.0"

  compartment_id = var.compartment_id

  vcn_name = var.vcn_name
  create_internet_gateway = "true"
}

module "vcn_subnet" {
  source  = "oracle-terraform-modules/vcn/oci//modules/subnet"
  version = "3.6.0"
  compartment_id = var.compartment_id
  ig_route_id    = module.vcn.ig_route_id
  nat_route_id   = module.vcn.nat_route_id
  vcn_id         = module.vcn.vcn_id
}

resource "oci_core_security_list" "LBSecList" {
  compartment_id  = var.compartment_id
  vcn_id          = module.vcn.vcn_id

  egress_security_rules {
        protocol    = "all"
        destination = "0.0.0.0/0"
        }
  ingress_security_rules {
        protocol    = "all"
        source = var.my_public_ip_address
        }
  ingress_security_rules {
        protocol    = "6"
        source = "0.0.0.0/0"
        tcp_options {
          max = "80" 
          min = "80"
        }
        }
  ingress_security_rules {
        protocol    = "6"
        source = "0.0.0.0/0"
        tcp_options {
          max = "443" 
          min = "443"
        }
        }
  ingress_security_rules {
        protocol    = "all"
        source = "10.0.0.0/24"
        }
  ingress_security_rules {
        protocol = "1"
        source = "0.0.0.0/0"
        icmp_options {
          type = "3"
          code = "4"
        }
  }
  ingress_security_rules {
        protocol = "1"
        source = "10.0.0.0/16"
        icmp_options {
          type = "3"
        }
  }
}

resource "oci_core_subnet" "vcn-private-subnet"{
  compartment_id    = var.compartment_id
  vcn_id            = module.vcn.vcn_id
  cidr_block        = "10.0.0.0/24"
  security_list_ids = [oci_core_security_list.LBSecList.id]

  route_table_id = module.vcn.ig_route_id
  display_name   = var.subnet_name
}


resource "oci_core_instance" "test_instance" {
    count = "${var.number_of_instances}"

    availability_domain = var.instance_availability_domain
    compartment_id = var.compartment_id
    shape = var.instance_shape
    display_name = "${var.instance_display_name}${count.index + 1}"

    preserve_boot_volume = false

    create_vnic_details {
    assign_private_dns_record = true
    assign_public_ip          = true
    subnet_id                 = oci_core_subnet.vcn-private-subnet.id
    }


    shape_config {
    memory_in_gbs = "6"
    ocpus         = "1"
  }
    source_details {
    source_id   = var.os_image_id
    source_type = "image"
  }
    metadata = {
        ssh_authorized_keys = "${file(var.ssh_public_key_file)}"
    }
}

resource "oci_network_load_balancer_network_load_balancer" "test_network_load_balancer" {
    compartment_id           = var.compartment_id
    display_name             = var.network_load_balancer_display_name
    is_private               = "false"
    subnet_id                = oci_core_subnet.vcn-private-subnet.id
}

resource "oci_network_load_balancer_listener" "test_listener" {
  default_backend_set_name = "k8s-api"
  name                     = "k8s-api"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.test_network_load_balancer.id
  port                     = "16433"
  protocol                 = "TCP"
  
}

resource "oci_network_load_balancer_backend_set" "test_backend_set" {
    health_checker {
        protocol = "HTTPS"
        
        interval_in_millis = "10000"
        timeout_in_millis = "3000"
        retries = "3"
        return_code = "401"
        url_path = "/"

    }
    name = "k8s-api"
    network_load_balancer_id = oci_network_load_balancer_network_load_balancer.test_network_load_balancer.id
    policy = "FIVE_TUPLE"

}

resource "oci_network_load_balancer_backend" "test_backend" {
    count = "${var.number_of_instances}"

    backend_set_name = "k8s-api"
    network_load_balancer_id = oci_network_load_balancer_network_load_balancer.test_network_load_balancer.id
    port = "16443"

    ip_address = oci_core_instance.test_instance[count.index].private_ip
    weight = "1"
}

output "public_ip_address" {
  value = "${formatlist("%s: %s", oci_core_instance.test_instance[*].display_name, oci_core_instance.test_instance[*].public_ip)}"
}