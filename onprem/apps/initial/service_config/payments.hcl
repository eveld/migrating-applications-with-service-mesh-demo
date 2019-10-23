service {
  name = "payments"
  id = "payments"
  address = "10.5.0.11"
  port = 9090
  
  tags      = ["v1"]
  meta      = {
    version = "1"
  }
  
  connect { 
    sidecar_service {
      port = 20000
      
      check {
        name = "Connect Envoy Sidecar"
        tcp = "10.5.0.11:20000"
        interval ="10s"
      }
      
      proxy {
        upstreams {
          destination_name = "currency"
          local_bind_address = "127.0.0.1"
          local_bind_port = 9091
        }
      }
    }  
  }
}