output "kubernetes_cluster_name" {
  value       = google_container_cluster.cluster.name
  description = "GKE cluster name"
} 

output "kubernetes_cluster_host" {
  value       = google_container_cluster.cluster.endpoint
  description = "GKE cluster host"
}

output "private_subnet" {
  value = google_compute_subnetwork.private.name
}

output "bastion_ip" {
  value       = google_compute_instance.bastion.network_interface[0].network_ip
  description = "Internal IP address of the bastion host"
}

output "gke_master_private_ip" {
  description = "Private IP address of GKE master"
  value       = google_container_cluster.cluster.private_cluster_config[0].master_ipv4_cidr_block
}

output "sql_instance_name" {
  description = "Name of the Cloud SQL PostgreSQL instance"
  value       = google_sql_database_instance.postgresql.name
}

output "sql_instance_ip" {
  description = "IP address of the Cloud SQL PostgreSQL instance"
  value       = google_sql_database_instance.postgresql.connection_name
}

output "dns_zone_name" {
  description = "Name of the DNS Managed Zone"
  value       = google_dns_managed_zone.primary.name
}

output "dns_zone_dns_name" {
  description = "DNS name of the Managed Zone"
  value       = google_dns_managed_zone.primary.dns_name
}