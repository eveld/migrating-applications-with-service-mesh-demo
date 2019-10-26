service {
  name = "payments"
  id = "payments-v2"
  port = 9090
  
  tags      = ["v2"]
  meta      = {
    version = "2"
  }
  
  connect { 
    sidecar_service {
      proxy {
        upstreams {
          destination_name = "currency"
          local_bind_port = 9091
        }
      }
    }  
  }
}