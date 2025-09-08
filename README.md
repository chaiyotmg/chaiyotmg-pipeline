# my private project pipeline


cat <<'EOF' > istio-gw-80443.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: gw-80443
  namespace: istio-system
spec:
  profile: empty
  # ให้ ingressgateway รันเป็น root เพื่อ bind <1024
  values:
    gateways:
      istio-ingressgateway:
        runAsRoot: true
  components:
    ingressGateways:
    - name: istio-ingressgateway
      enabled: true
      k8s:
        # service ต้องอยู่ใต้ k8s.service (ไม่ใช่ values)
        service:
          type: ClusterIP
          ports:
          - name: http2
            port: 80
            targetPort: 80
          - name: https
            port: 443
            targetPort: 443
        overlays:
        - apiVersion: apps/v1
          kind: Deployment
          name: istio-ingressgateway
          patches:
          # ใช้เครือข่ายโฮสต์ + DNS policy ให้สอดคล้อง
          - path: spec.template.spec.hostNetwork
            value: true
          - path: spec.template.spec.dnsPolicy
            value: ClusterFirstWithHostNet
          # ให้ Envoy ฟังพอร์ต 80/443 แทน 8080/8443
          - path: spec.template.spec.containers.[name:istio-proxy].ports
            value:
            - containerPort: 80
              name: http2
              protocol: TCP
            - containerPort: 443
              name: https
              protocol: TCP
          # (ซ้ำซ้อนกับ runAsRoot แต่เผื่อดิสโทรบางตัว) เพิ่มสิทธิ์ bind <1024
          - path: spec.template.spec.containers.[name:istio-proxy].securityContext.capabilities.add
            value:
            - NET_BIND_SERVICE
EOF

# ติดตั้ง/อัปเดต
istioctl install -f istio-gw-80443.yaml -y
kubectl -n istio-system rollout status deploy/istio-ingressgateway



kubectl -n istio-system patch deploy istio-ingressgateway --type='json' -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/securityContext","value":{
    "runAsUser": 0,
    "runAsNonRoot": false,
    "capabilities": {"add": ["NET_BIND_SERVICE"]}
  }}
]'


# Gateway (HTTP/80; ถ้ามี TLS แล้ว เพิ่มบล็อก 443 ได้ภายหลัง)
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: public-gw
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
  - port: { number: 80, name: http, protocol: HTTP }
    hosts:
    - portfolio-api.chaiyot.dev
EOF

# VirtualService route ไป service echo ใน ns microservice-dev
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: echo
  namespace: microservice-dev
spec:
  hosts: [ "portfolio-api.chaiyot.dev" ]
  gateways: [ "istio-system/public-gw" ]
  http:
  - match:
    - uri: { prefix: "/" }
    route:
    - destination:
        host: echo.microservice-dev.svc.cluster.local
        port: { number: 80 }
EOF
