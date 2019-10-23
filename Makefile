.PHONY: onprem cloud expose nuke tools apps migrate world

PROJECT=yard

CLOUD_PATH="$(PWD)/cloud"
ONPREM_PATH="$(PWD)/onprem"

APPS_PATH="$(ONPREM_PATH)/apps"

INITIAL_PATH="$(APPS_PATH)/initial"
CURRENCY_PATH="$(APPS_PATH)/currency"
MIGRATE_PATH="$(APPS_PATH)/migrate"

world: onprem cloud expose apps currency

onprem:
	docker-compose -p $(PROJECT) --project-directory $(ONPREM_PATH) -f $(ONPREM_PATH)/docker-compose.yaml up -d

destroy-onprem:
	docker-compose -p $(PROJECT) --project-directory $(ONPREM_PATH) -f $(ONPREM_PATH)/docker-compose.yaml down -v

cloud:
	yard up --type k3s --name cloud --consul-port 18500 --dashboard-port 18443 --network $(PROJECT)_wan --consul-values $(CLOUD_PATH)/consul-values.yaml

destroy-cloud:
	yard down --name cloud

expose: expose-consul expose-gateway

expose-consul:
	yard expose --name cloud --bind-ip none \
	--network $(PROJECT)_wan \
	--network-ip 192.169.7.30 \
	--service-name svc/consul-consul-server \
	--port 8600:8600 \
	--port 8500:8500 \
	--port 8302:8302 \
	--port 8301:8301 \
	--port 8300:8300

expose-gateway:
	yard expose --name cloud --bind-ip none \
	--network $(PROJECT)_wan \
	--network-ip 192.169.7.40 \
	--service-name svc/consul-consul-mesh-gateway \
	--port 443:443

nuke: destroy-cloud destroy-apps destroy-currency destroy-onprem

tools:
	yard tools --name cloud

apps:
	docker-compose -p $(PROJECT) --project-directory $(INITIAL_PATH) -f $(INITIAL_PATH)/docker-compose.yaml up -d

destroy-apps:
	docker-compose -p $(PROJECT) --project-directory $(INITIAL_PATH) -f $(INITIAL_PATH)/docker-compose.yaml down -v

currency:
	docker-compose -p $(PROJECT) --project-directory $(CURRENCY_PATH) -f $(CURRENCY_PATH)/docker-compose.yaml up -d

destroy-currency:
	docker-compose -p $(PROJECT) --project-directory $(CURRENCY_PATH) -f $(CURRENCY_PATH)/docker-compose.yaml down -v

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