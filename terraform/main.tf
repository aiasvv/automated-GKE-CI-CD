resource "google_compute_network" "vpc" {
  name                    = "vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "private" {
  name                     = "private"
  region                   = var.region
  network                  = google_compute_network.vpc.self_link
  ip_cidr_range            = "10.0.0.0/24"
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods-subnet"
    ip_cidr_range = "10.0.1.0/24"
  }
  secondary_ip_range {
    range_name    = "services-subnet"
    ip_cidr_range = "10.0.2.0/24"
  }

  depends_on = [
    google_compute_network.vpc,
  ]
}

resource "google_compute_address" "ip_addr" {
  name         = "ip"
  subnetwork   = google_compute_subnetwork.private.name
  address_type = "INTERNAL"
  address      = "10.0.0.6"
  region       = var.region
}

resource "google_compute_instance" "bastion" {
  name         = "bastion"
  zone         = var.zone
  machine_type = "e2-medium"

  tags = ["bastion", "kubernetes-api"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = google_compute_network.vpc.name
    subnetwork = google_compute_subnetwork.private.name
    network_ip = google_compute_address.ip_addr.address
  }

  metadata_startup_script = file("${path.module}/startup-script.sh")

  service_account {
    email  = var.service_account
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_firewall" "ssh" {
  project       = var.project
  name          = "allow-bastion-ssh"
  network       = google_compute_network.vpc.name

  allow {
    protocol    = "tcp"
    ports       = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["bastion"]
}

resource "google_compute_firewall" "allow_kubernetes_api" {
  project       = var.project
  name          = "allow-kubernetes-api"
  network       = google_compute_network.vpc.name

  allow {
    protocol    = "tcp"
    ports       = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["kubernetes-api"]
}

resource "google_compute_router" "router" {
  name    = "router"
  region  = var.region
  network = google_compute_network.vpc.name
}

module "cloud-nat" {
  source     = "terraform-google-modules/cloud-nat/google"
  version    = "~> 1.2"
  project_id = var.project
  region     = var.region
  router     = google_compute_router.router.name
  name       = "nat"
}

resource "google_container_cluster" "cluster" {
  name                     = "cluster"
  location                 = "us-central1-c"
  network                  = google_compute_network.vpc.self_link
  subnetwork               = google_compute_subnetwork.private.self_link
  remove_default_node_pool = true
  deletion_protection      = false
  initial_node_count       = 1

  private_cluster_config {
    enable_private_endpoint = true
    enable_private_nodes    = true
    master_ipv4_cidr_block  = "10.13.0.0/28"
  }

  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "10.11.0.0/21"
    services_ipv4_cidr_block = "10.12.0.0/21"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "${google_compute_instance.bastion.network_interface[0].network_ip}/32"
      display_name = "my-network"
    }
  }

  addons_config {
    horizontal_pod_autoscaling {
      disabled = false
    }
    http_load_balancing {
      disabled = false
    }
    network_policy_config {
      disabled = false
    }
  }

  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"
  enable_legacy_abac = false
}

resource "google_container_node_pool" "primary" {
  name       = "primary"
  location   = "us-central1-c"
  cluster    = google_container_cluster.cluster.name
  node_count = 3

  node_config {
    machine_type    = "e2-medium"
    disk_size_gb    = 50

    service_account = var.service_account
    oauth_scopes    = var.oauth_scopes

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}

resource "google_sql_database_instance" "postgresql" {
  name                = "postgres"
  project             = var.project
  region              = var.region
  database_version    = "POSTGRES_11"
  deletion_protection = false

  settings {
    tier = "db-f1-micro"
    
    location_preference {
      zone = var.zone
    }

    ip_configuration {
      ipv4_enabled = true
      authorized_networks {
        value = "0.0.0.0/0"
      }
    }
  }
}

resource "google_sql_database" "postgresql_db" {
  name       = "postgres11"
  project    = var.project
  instance   = google_sql_database_instance.postgresql.name
  
  depends_on = [google_sql_database_instance.postgresql]
}

resource "google_sql_user" "postgresql_user" {
  name       = "aia"
  project    = var.project
  instance   = google_sql_database_instance.postgresql.name
  password   = "1234"
  
  depends_on = [google_sql_database_instance.postgresql]
}

resource "google_dns_managed_zone" "primary" {
  name        = "dns"
  dns_name    = "aiasv.dev."
  description = "Managed zone for aiasv.dev"
  project     = var.project

  visibility  = "public"
}