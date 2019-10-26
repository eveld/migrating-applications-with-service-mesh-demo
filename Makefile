.PHONY: onprem cloud expose nuke tools apps migrate world multi-cloud

PROJECT=yard

CLOUD_PATH="$(PWD)/cloud"
MULTICLOUD_PATH="$(PWD)/multi-cloud"
ONPREM_PATH="$(PWD)/onprem"

CLUSTER_PATH="$(ONPREM_PATH)/cluster"
GATEWAY_PATH="$(ONPREM_PATH)/gateway"
APPS_PATH="$(ONPREM_PATH)/apps"

MONOLITH_PATH="$(APPS_PATH)/monolith"
CURRENCY_PATH="$(APPS_PATH)/currency"
PAYMENTS_PATH="$(APPS_PATH)/payments-v2"

CLOUD_CURRENCY_PATH="$(CLOUD_PATH)/currency"

world: onprem monolith currency currency-path-router payments-v2 payments-v2-router payments-v2-splitter-100 cloud expose-cloud currency-v2 onprem-gateway currency-v2-router multi-cloud expose-multi-cloud multi-cloud-service

#
# Base environment
#
onprem:
	docker-compose -p $(PROJECT) --project-directory $(CLUSTER_PATH) -f $(CLUSTER_PATH)/docker-compose.yaml up -d
	sleep 5
	yard exec --name cloud -- consul config write /work/onprem/cluster/central_config/global-defaults.hcl
destroy-onprem:
	yard exec --name cloud -- consul config delete -kind service-defaults -name global
	docker-compose -p $(PROJECT) --project-directory $(CLUSTER_PATH) -f $(CLUSTER_PATH)/docker-compose.yaml down -v


#
# Monolith
#
monolith:
	docker-compose -p $(PROJECT) --project-directory $(MONOLITH_PATH) -f $(MONOLITH_PATH)/docker-compose.yaml up -d
destroy-monolith:
	docker-compose -p $(PROJECT) --project-directory $(MONOLITH_PATH) -f $(MONOLITH_PATH)/docker-compose.yaml down -v


#
# Deploy currency
#
currency:
	docker-compose -p $(PROJECT) --project-directory $(CURRENCY_PATH) -f $(CURRENCY_PATH)/docker-compose.yaml up -d
destroy-currency:
	docker-compose -p $(PROJECT) --project-directory $(CURRENCY_PATH) -f $(CURRENCY_PATH)/docker-compose.yaml down -v


#
# Send test group users to currency when visiting /currency
#
currency-header-router:
	yard exec --name cloud -- consul config write /work/onprem/apps/currency/central_config/payments-header-router.hcl
destroy-currency-header-router:
	yard exec --name cloud -- consul config delete -kind service-router -name payments


#
# Send everyone to currency when visiting /currency
#
currency-path-router:
	yard exec --name cloud -- consul config write /work/onprem/apps/currency/central_config/payments-path-router.hcl
destroy-currency-path-router:
	yard exec --name cloud -- consul config delete -kind service-router -name payments


#
# Deploy payments v2
#
payments-v2:
	docker-compose -p $(PROJECT) --project-directory $(PAYMENTS_PATH) -f $(PAYMENTS_PATH)/docker-compose.yaml up -d
	yard exec --name cloud -- consul config write /work/onprem/apps/payments-v2/central_config/payments-resolver.hcl
destroy-payments-v2:
	docker-compose -p $(PROJECT) --project-directory $(PAYMENTS_PATH) -f $(PAYMENTS_PATH)/docker-compose.yaml down -v
	yard exec --name cloud -- consul config delete -kind service-resolver -name payments


#
# Route test group to v2
#
payments-v2-router:
	yard exec --name cloud -- consul config write /work/onprem/apps/payments-v2/central_config/payments-router.hcl
destroy-payments-v2-router:
	yard exec --name cloud -- consul config delete -kind service-router -name payments


#
# Create traffic splitter between payments v1 and v2
#
payments-v2-splitter:
	yard exec --name cloud -- consul config write /work/onprem/apps/payments-v2/central_config/payments-splitter.hcl
payments-v2-splitter-50:
	yard exec --name cloud -- consul config write /work/onprem/apps/payments-v2/central_config/payments-splitter-50.hcl
payments-v2-splitter-100:
	yard exec --name cloud -- consul config write /work/onprem/apps/payments-v2/central_config/payments-splitter-100.hcl
destroy-payments-v2-splitter:
	yard exec --name cloud -- consul config delete -kind service-splitter -name payments


#
# Create a kubernetes cluster
#
cloud:
	yard up --type k3s --name cloud --consul-port 18500 --dashboard-port 18443 --network $(PROJECT)_wan --network-ip "192.169.7.100" --consul-values $(CLOUD_PATH)/consul-values.yaml
destroy-cloud:
	yard down --name cloud


#
# Expose consul and mesh-gateway on wan
#
expose-cloud: expose-cloud-consul expose-cloud-gateway
expose-cloud-consul:
	yard expose --name cloud --bind-ip none \
	--network $(PROJECT)_wan \
	--network-ip 192.169.7.130 \
	--service-name svc/consul-consul-server \
	--port 8600:8600 \
	--port 8500:8500 \
	--port 8302:8302 \
	--port 8301:8301 \
	--port 8300:8300
expose-cloud-gateway:
	yard expose --name cloud --bind-ip none \
	--network $(PROJECT)_wan \
	--network-ip 192.169.7.140 \
	--service-name svc/consul-consul-mesh-gateway \
	--port 443:443


#
# Deploy an updated version of currency in the cloud
#
currency-v2:
	yard exec --name cloud -- kubectl apply -f /work/cloud/currency/currency.yaml
	
destroy-currency-v2:
	yard exec --name cloud -- kubectl delete -f /work/cloud/currency/currency.yaml
	yard exec --name cloud -- consul config delete -kind service-resolver -name currency


#
# Expose on-prem gateway
#
onprem-gateway:
	docker-compose -p $(PROJECT) --project-directory $(GATEWAY_PATH) -f $(GATEWAY_PATH)/docker-compose.yaml up -d
destroy-onprem-gateway:
	docker-compose -p $(PROJECT) --project-directory $(GATEWAY_PATH) -f $(GATEWAY_PATH)/docker-compose.yaml down -v


#
# Route traffic to the updated version of currency in the cloud
#
currency-v2-router:
	yard exec --name cloud -- consul config write /work/cloud/currency/currency-resolver.hcl
destroy-currency-v2-router:
	yard exec --name cloud -- consul config delete -kind service-resolver -name currency


#
# Create another kubernetes cluster
#
multi-cloud:
	yard up --type k3s --name multi-cloud --consul-port 28500 --dashboard-port 28443 --network $(PROJECT)_wan --network-ip "192.169.7.200" --consul-values $(MULTICLOUD_PATH)/consul-values.yaml
destroy-multi-cloud:
	yard down --name multi-cloud


#
# Expose consul and mesh-gateway on wan
#
expose-multi-cloud: expose-multi-cloud-consul expose-multi-cloud-gateway
expose-multi-cloud-consul:
	yard expose --name multi-cloud --bind-ip none \
	--network $(PROJECT)_wan \
	--network-ip 192.169.7.230 \
	--service-name svc/consul-consul-server \
	--port 8600:8600 \
	--port 8500:8500 \
	--port 8302:8302 \
	--port 8301:8301 \
	--port 8300:8300
expose-multi-cloud-gateway:
	yard expose --name multi-cloud --bind-ip none \
	--network $(PROJECT)_wan \
	--network-ip 192.169.7.240 \
	--service-name svc/consul-consul-mesh-gateway \
	--port 443:443


#
# Deploy multi-cluster services
#
multi-cloud-service: deploy-multi-cloud-service expose-multi-cloud-service
deploy-multi-cloud-service:
	yard exec --name cloud -- kubectl apply -f /work/multi-cloud/api.yaml
	yard exec --name cloud -- consul config write /work/multi-cloud/space-resolver.hcl
	yard exec --name multi-cloud -- kubectl apply -f /work/multi-cloud/backend.yaml
destroy-multi-cloud-service:
	yard exec --name cloud -- consul config delete -kind service-resolver -name backend
	yard exec --name cloud -- kubectl delete -f /work/multi-cloud/api.yaml
	yard exec --name multi-cloud -- kubectl delete -f /work/multi-cloud/backend.yaml
expose-multi-cloud-service:
	yard expose --name cloud \
	--service-name svc/api \
	--port 19090:9090


#
# Connect the multi-cluster services to onprem
#
connect-onprem:
	yard exec --name multi-cloud -- kubectl apply -f /work/connect/backend.yaml
	yard exec --name multi-cloud -- consul config write /work/connect/onprem-resolver.hcl


#
# Blow up everything
#
armageddon:
	docker ps -aq | xargs docker rm -f || true
	docker network ls -q | xargs docker network rm || true
	docker volume ls -q | xargs docker volume rm || true


#
# Launch utils
#
tools:
	yard tools --name cloud