service {
  name = "api"
  id = "api"
  address = "10.5.0.10"
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
        tcp = "10.5.0.10:20000"
        interval ="10s"
      }
      
      proxy {
        upstreams {
          destination_name = "payments"
          local_bind_address = "127.0.0.1"
          local_bind_port = 9091
        }

        upstreams {
          destination_name = "auth"
          local_bind_address = "127.0.0.1"
          local_bind_port = 9092
        }
      }
    }  
  }
}