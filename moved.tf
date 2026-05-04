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
