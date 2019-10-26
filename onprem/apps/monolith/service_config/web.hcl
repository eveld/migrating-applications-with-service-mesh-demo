service {
  name = "web"
  id = "web"
  port = 9090
  
  tags = ["v1"]
  meta = {
    version = "1"
  }
  
  connect { 
    sidecar_service {
      proxy {
        upstreams {
          destination_name = "payments"
          local_bind_port = 9091
        }
      }
    }  
  }
}