# Demo

## Step 1 - The monolith

```shell
# Create Consul cluster
make onprem

# Spin up the monolith
make monolith

# Try out the application
curl http://localhost:9090
open http://localhost:9090/ui
```

![Monolith](docs/images/step1.png)

### Components

- web: upstream of payments
- payments: no upstreams

## Step 2 - First microservice

```shell
# Deploy the currency service
make currency

# Allow only traffic containing specific headers to reach the currency service
make currency-header-router

# Goes to payments
curl http://localhost:9090/currency

# Goes to currency
curl -H "group: dev" http://localhost:9090/currency

# Route traffic for /currency to the currency service
make currency-path-router

# Goes to payments
curl http://localhost:9090

# Goes to currency
curl http://localhost:9090/currency
```

![Monolith](docs/images/step2.png)

### Components

- web: upstream of payments, and route dev group to currency
- payments: no upstreams
- currency: no upstreams

## Step 3 - A/B testing

```shell
# Deploy payments v2 and define 2 subsets based on version
make payments-v2

# Goes to payments v1
curl http://localhost:9090

# Send the test group to v2 of payments
make payments-v2-router

# Goes to payments v1
curl http://localhost:9090

# Goes to payments v2
curl -H "group: test" http://localhost:9090
```

![Monolith](docs/images/step3.png)

### Components

- web: upstream of payments, and route test group to payments-v2
- payments: no upstreams
- payments-v2: upstream of currency
- currency: no upstreams

## Step 4 - Canary release

```shell
# Create a traffic-split between payments v1 and v2
make payments-v2-splitter

# Send 50% of the traffic to v2
make payments-v2-splitter-50

# Send 100% of the traffic to v2
make payments-v2-splitter-100
```

![Monolith](docs/images/step4.png)

## Step 5 - Multi-cluster

```shell
make cloud
```

![Monolith](docs/images/step5.png)
