#!/bin/sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
echo $DIR
###########
# Create a directory for the k8s .yaml files
###########
mkdir -p ${DIR}/../tmp/hashicups

###########
# Install Postgres client for testing
###########
#sudo apt-get update
#sudo apt-get install -y postgresql-client
#apt install -y postgresql-client-common

###########
# Install Vault Client
###########
#vault_version=1.5.3
#wget "https://releases.hashicorp.com/vault/${vault_version}/vault_${vault_version}_linux_amd64.zip"
#unzip "vault_${vault_version}_linux_amd64.zip"
#mv vault /usr/local/bin/vault
#chmod +x /usr/local/bin/vault
#rm -f "vault_${vault_version}_linux_amd64.zip"

###########
# Configure Consul Helm Chart values
###########
cat <<-EOF > ${DIR}/../tmp/us-central-values.yaml
global:
  datacenter: uscentral
  #image: "consul:1.8.2"
  #imageK8S: "hashicorp/consul-k8s:0.18.1"

ui:
  enabled: true
  service:
    type: 'LoadBalancer'

server:
  replicas: 1
  bootstrapExpect: 1

client:
  enabled: true
  grpc: true

connectInject:
  enabled: true

syncCatalog:
  enabled: true
  #toConsul: true
  #toK8S: false
  #default: true
EOF


###########
# Install Consul with the Helm Chart
###########
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install -f ${DIR}/../tmp/us-central-values.yaml us-central hashicorp/consul

# Wait for consul server pod to be ready
status=""
while [ -z "${status}" ]; do
  sleep 3
  status=$(kubectl get pods | grep "uscentral-consul-server.*1/1")
done

###########
# Set up Postgres Products DB Kubernetes Deployment
###########
cat <<-EOF > ${DIR}/../tmp/hashicups/products-db.yml
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  labels:
    app: postgres
spec:
  type: ClusterIP
  ports:
    - port: 5432
      targetPort: 5432
  selector:
    app: postgres
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
spec:
  replicas: 1
  selector:
    matchLabels:
      service: postgres
      app: postgres
  template:
    metadata:
      labels:
        service: postgres
        app: postgres
      annotations:
        consul.hashicorp.com/connect-inject: "true"
    spec:
      containers:
        - name: postgres
          image: hashicorpdemoapp/product-api-db:v0.0.11
          ports:
            - containerPort: 5432
          env:
            - name: POSTGRES_DB
              value: products
            - name: POSTGRES_USER
              value: postgres
            - name: POSTGRES_PASSWORD
              value: password
          volumeMounts:
            - mountPath: "/var/lib/postgresql/data"
              name: "pgdata"
      volumes:
        - name: pgdata
          emptyDir: {}
EOF


###########
# Set up Products API Kubernetes Deployment
###########
cat <<-EOF > ${DIR}/../tmp/hashicups/products-api.yml
---
# Service to expose web frontend
apiVersion: v1
kind: Service
metadata:
  name: products-api-service
  labels:
    app: products-api
spec:
  selector:
    app: products-api
  ports:
    - name: http
      protocol: TCP
      port: 9090
      targetPort: 9090
---
# Web frontend
apiVersion: apps/v1
kind: Deployment
metadata:
  name: products-api-deployment
  labels:
    app: products-api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: products-api
  template:
    metadata:
      labels:
        app: products-api
      annotations:
        prometheus.io/scrape: "true"
        consul.hashicorp.com/connect-inject: "true"
        consul.hashicorp.com/connect-service-upstreams: "postgres:5432"
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/agent-inject-status: "update"
        vault.hashicorp.com/namespace: "uscentral"
        vault.hashicorp.com/auth-path: "auth/k8s"
        vault.hashicorp.com/agent-inject-secret-db-creds: "kv/db/postgres/product-db-creds"
        vault.hashicorp.com/agent-inject-template-db-creds: |
          {
          {{ with secret "kv/db/postgres/product-db-creds" -}}
            "db_connection": "host=localhost port=5432 user={{ .Data.username }} password={{ .Data.password }} dbname=products sslmode=disable",
            "bind_address": ":9090",
            "metrics_address": ":9103"
          {{- end }}
          }
        vault.hashicorp.com/role: "products-api"
    spec:
      serviceAccountName: products-api
      containers:
        - name: products-api
          image: hashicorpdemoapp/product-api:v0.0.11
          ports:
            - containerPort: 9090
            - containerPort: 9102
          env:
            - name: "CONFIG_FILE"
              value: "/vault/secrets/db-creds"
          livenessProbe:
            httpGet:
              path: /health
              port: 9090
            initialDelaySeconds: 15
            timeoutSeconds: 1
            periodSeconds: 10
            failureThreshold: 30
---
# https://www.vaultproject.io/docs/auth/kubernetes/#configuring-kubernetes
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: role-tokenreview-binding
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
  - kind: ServiceAccount
    name: products-api
    namespace: default
EOF

###########
# Set up Public API Kubernetes Deployment
###########
cat <<-EOF > ${DIR}/../tmp/hashicups/public-api.yml
---
apiVersion: v1
kind: Service
metadata:
  name: public-api-svc
  labels:
    app: public-api
spec:
  type: ClusterIP
  ports:
    - port: 8080
      targetPort: 8080
  selector:
    app: public-api
---
apiVersion: v1
kind: Service
metadata:
  name: public-api-ui
  labels:
    app: public-api
spec:
  type: NodePort
  ports:
    - port: 8080
      targetPort: 8080
      nodePort: 30080
  selector:
    app: public-api
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: public-api
spec:
  replicas: 1
  selector:
    matchLabels:
      service: public-api
      app: public-api
  template:
    metadata:
      labels:
        service: public-api
        app: public-api
      annotations:
        prometheus.io/scrape: "true"
        consul.hashicorp.com/connect-inject: "true"
        consul.hashicorp.com/connect-service-upstreams: "products-api:9090"
    spec:
      containers:
        - name: public-api
          image: hashicorpdemoapp/public-api:v0.0.1
          ports:
            - containerPort: 8080
          env:
            - name: BIND_ADDRESS
              value: ":8080"
            - name: PRODUCTS_API_URI
              value: "http://localhost:9090"
EOF


###########
# Set up Frontend Kubernetes Deployment
###########

cat <<-EOF > ${DIR}/../tmp/hashicups/frontend.yml
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-ui
  labels:
    app: frontend
spec:
  type: NodePort
  selector:
    app: frontend
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 80
    nodePort: 30090
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-configmap
data:
  config: |
    # /etc/nginx/conf.d/default.conf
    server {
        listen       80;
        server_name  localhost;
        #charset koi8-r;
        #access_log  /var/log/nginx/host.access.log  main;
        location / {
            root   /usr/share/nginx/html;
            index  index.html index.htm;
        }
        # Proxy pass the api location to save CORS
        # Use location exposed by Consul connect
        location /api {
            proxy_pass http://127.0.0.1:8080;
        }
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   /usr/share/nginx/html;
        }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      service: frontend
      app: frontend
  template:
    metadata:
      labels:
        service: frontend
        app: frontend
      annotations:
        prometheus.io/scrape: "true"
        consul.hashicorp.com/connect-inject: "true"
        consul.hashicorp.com/connect-service-upstreams: "public-api:8080"
    spec:
      volumes:
      - name: config
        configMap:
          name: nginx-configmap
          items:
          - key: config
            path: default.conf
      containers:
        - name: frontend
          image: hashicorpdemoapp/frontend:v0.0.3
          ports:
            - containerPort: 80
          volumeMounts:
            - name: config
              mountPath: /etc/nginx/conf.d
              readOnly: true
EOF


###########
# Set up Products API Service Account
###########
cat <<-EOF > ${DIR}/../tmp/hashicups/products-api-service-account.yml
# Service account to allow pod access to Vault via K8s auth
apiVersion: v1
kind: ServiceAccount
metadata:
  name: products-api
automountServiceAccountToken: true
EOF

kubectl apply -f ${DIR}/../tmp/hashicups/products-api-service-account.yml

exit 0