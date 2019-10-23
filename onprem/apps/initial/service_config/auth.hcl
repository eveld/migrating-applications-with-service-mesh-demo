service {
  name = "auth"
  id = "auth"
  address = "10.5.0.13"
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
        tcp = "10.5.0.13:20000"
        interval ="10s"
      }
    }  
  }
}