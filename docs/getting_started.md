---
layout: default
title: Getting Started
nav_order: 2 
---

# Getting Started

This exercise familiarizes you with Consul and how it works with your application.

Run the file `docker-compose.yml` in the `examples\getting_started` to start a Consul server and two services.

```
➜ docker-compose up  
Creating network "getting_started_vpcbr" with driver "bridge"
Creating getting_started_api_1    ... done
Creating getting_started_consul_1 ... done
Creating getting_started_web_1    ... done
Attaching to getting_started_api_1, getting_started_consul_1, getting_started_web_1
```

You should be able to access the consul server in your browser at [http://localhost:8500](http://localhost:8500)

![](images/getting_started/consul_ui.png)