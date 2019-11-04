kind = "service-splitter"
name = "api"
splits = [
  {
    weight = 50
  },
  {
    weight  = 50
    service = "api-cloud"
  },
]
