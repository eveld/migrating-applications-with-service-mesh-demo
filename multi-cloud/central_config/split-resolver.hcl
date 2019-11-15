kind = "service-resolver"
name = "currency"

default_subset = "onprem"

subsets = {
  onprem = {
      filter = "Node.Datacenter == onprem"
  }
  cloud = {
      filter = "Node.Datacenter == cloud"
  }
}

failover = {
   "*" = {
      datacenters = ["onprem", "cloud"]
  }
}