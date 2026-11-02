moved {
  from = hcloud_server.workers_new
  to   = hcloud_server.workers
}

removed {
  from = hcloud_floating_ip_assignment.this

  lifecycle {
    destroy = false
  }
}

# Replaced by talos_cluster.this, which adopts the already-bootstrapped cluster.
removed {
  from = talos_machine_bootstrap.this

  lifecycle {
    destroy = false
  }
}
