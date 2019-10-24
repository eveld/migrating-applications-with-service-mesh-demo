.PHONY: onprem cloud expose nuke tools apps migrate world

PROJECT=yard

CLOUD_PATH="$(PWD)/cloud"
ONPREM_PATH="$(PWD)/onprem"

CLUSTER_PATH="$(ONPREM_PATH)/cluster"
GATEWAY_PATH="$(ONPREM_PATH)/gateway"
APPS_PATH="$(ONPREM_PATH)/apps"

MONOLITH_PATH="$(APPS_PATH)/monolith"
CURRENCY_PATH="$(APPS_PATH)/currency"
PAYMENTS_PATH="$(APPS_PATH)/payments-v2"

INITIAL_PATH="$(APPS_PATH)/initial"
MIGRATE_PATH="$(APPS_PATH)/migrate"

world: onprem cloud expose apps currency

#
# Base environment
#
onprem:
	docker-compose -p $(PROJECT) --project-directory $(CLUSTER_PATH) -f $(CLUSTER_PATH)/docker-compose.yaml up -d
destroy-onprem:
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
#
#

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


cloud:
	yard up --type k3s --name cloud --consul-port 18500 --dashboard-port 18443 --network $(PROJECT)_wan --consul-values $(CLOUD_PATH)/consul-values.yaml

destroy-cloud:
	yard down --name cloud

expose: expose-consul expose-gateway

expose-consul:
	yard expose --name cloud --bind-ip none \
	--network $(PROJECT)_wan \
	--network-ip 192.169.7.130 \
	--service-name svc/consul-consul-server \
	--port 8600:8600 \
	--port 8500:8500 \
	--port 8302:8302 \
	--port 8301:8301 \
	--port 8300:8300

expose-gateway:
	yard expose --name cloud --bind-ip none \
	--network $(PROJECT)_wan \
	--network-ip 192.169.7.140 \
	--service-name svc/consul-consul-mesh-gateway \
	--port 443:443

nuke: destroy-cloud destroy-apps destroy-currency destroy-onprem

armageddon:
	docker ps -aq | xargs docker rm -f || true
	docker network ls -q | xargs docker network rm || true
	docker volume ls -q | xargs docker volume rm || true

tools:
	yard tools --name cloud