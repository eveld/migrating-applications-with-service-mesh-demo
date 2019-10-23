service {
  name = "currency"
  id = "currency"
  address = "10.5.0.12"
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
        tcp = "10.5.0.12:20000"
        interval ="10s"
      }
    }  
  }
}