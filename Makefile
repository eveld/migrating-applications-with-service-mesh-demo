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

world: onprem monolith currency currency-path-router payments-v2 payments-v2-router payments-v2-splitter-100 cloud

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
# Expose on-prem gateway
#
onprem-gateway:
	docker-compose -p $(PROJECT) --project-directory $(GATEWAY_PATH) -f $(GATEWAY_PATH)/docker-compose.yaml up -d
destroy-onprem-gateway:
	docker-compose -p $(PROJECT) --project-directory $(GATEWAY_PATH) -f $(GATEWAY_PATH)/docker-compose.yaml down -v


migrate: destroy-currency
	docker run \
	--rm -it \
	-v $(HOME)/.shipyard/cloud/:/files \
	-v $(PWD):/work \
	-w /work \
	-e "KUBECONFIG=/files/kubeconfig-docker.yml" \
	--network k3d-cloud \
	nicholasjackson/consul-k8s-tools kubectl apply -f /work/cloud/migrate/currency.yaml
	docker run \
	--rm -it \
	-v $(HOME)/.shipyard/cloud:/files \
	-v $(PWD):/work \
	-w /work \
	-e "CONSUL_HTTP_ADDR=http://k3d-cloud-server:30443" \
	--network k3d-cloud \
	nicholasjackson/consul-k8s-tools consul config write /work/cloud/migrate/redirect.hcl


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
expose-cloud: expose-consul expose-gateway
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
# Create another kubernetes cluster
#
multi-cloud:
	yard up --type k3s --name multi-cloud --consul-port 28500 --dashboard-port 28443 --network $(PROJECT)_wan --network-ip "192.169.7.200" --consul-values $(MULTICLOUD_PATH)/consul-values.yaml
destroy-multi-cloud:
	yard down --name multi-cloud


#
# Expose consul and mesh-gateway on wan
#
expose-multi-cloud: expose-multi-consul expose-multi-gateway
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
# Create the cloud cluster with kubernetes
#
deploy-multi-cloud-service:
	yard exec --name cloud -- kubectl apply -f /work/multi-cloud/a.yaml
	yard exec --name multi-cloud -- kubectl apply -f /work/multi-cloud/b.yaml
	yard exec --name cloud -- consul config write /work/multi-cloud/space-resolver.hcl
	yard exec --name cloud -- consul config write /work/multi-cloud/onprem-resolver.hcl


#
# Expose the multi-cloud service on localhost
#
expose-multi-cloud-service:
	yard expose --name cloud \
	--service-name svc/a \
	--port 19090:9090


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