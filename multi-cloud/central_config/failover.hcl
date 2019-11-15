kind = "service-resolver"
name = "currency"

failover = {
  "*" = {
      datacenters = ["onprem", "cloud"]
  }
}