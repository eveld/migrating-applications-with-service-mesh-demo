kind = "service-router"
name = "payments"
routes = [
  {
    match {
      http {
        path_prefix = "/currency"
        header = [
          {
            name  = "group"
            exact = "dev"
          },
        ]
      }
    }

    destination {
      service = "currency"
    }
  }
]