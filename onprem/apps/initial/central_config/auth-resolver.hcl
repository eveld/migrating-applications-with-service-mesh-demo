kind = "service-resolver"
name = "auth"

redirect {
  service = "auth"
  datacenter = "onprem"
}