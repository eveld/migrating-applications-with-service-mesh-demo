kind = "service-splitter",
name = "currency"

splits = [
  {
    weight = 50,
    service_subset = "onprem"
  },
  {
    weight = 50,
    service_subset = "cloud"
  }
]