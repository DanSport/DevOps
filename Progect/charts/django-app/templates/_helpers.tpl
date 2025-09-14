# helpers
cat > lesson-7/charts/django-app/templates/_helpers.tpl <<'EOF'
{{- define "django-app.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "django-app.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if .Values.nameOverride -}}
{{- printf "%s-%s" .Release.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "django-app.labels" -}}
app.kubernetes.io/name: {{ include "django-app.name" . }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
EOF

# deployment (з явним command -> Django без entrypoint.sh)
cat > lesson-7/charts/django-app/templates/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "django-app.fullname" . }}
  labels:
    {{- include "django-app.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount | default 2 }}
  selector:
    matchLabels:
      app: {{ include "django-app.name" . }}
  template:
    metadata:
      labels:
        app: {{ include "django-app.name" . }}
        {{- include "django-app.labels" . | nindent 8 }}
    spec:
      containers:
        - name: {{ include "django-app.name" . }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 8000
          command: ["python","django_app/manage.py","runserver","0.0.0.0:8000"]
          envFrom:
            - configMapRef:
                name: {{ include "django-app.fullname" . }}-config
          resources:
            {{- toYaml (.Values.resources | default dict) | nindent 12 }}
EOF

# service (80 -> 8000)
cat > lesson-7/charts/django-app/templates/service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: {{ include "django-app.fullname" . }}
  labels:
    {{- include "django-app.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type | default "LoadBalancer" }}
  selector:
    app: {{ include "django-app.name" . }}
  ports:
    - name: http
      port: {{ .Values.service.port | default 80 }}
      targetPort: {{ .Values.service.targetPort | default 8000 }}
EOF

# configmap (мінімум — ALLOWED_HOSTS="*")
cat > lesson-7/charts/django-app/templates/configmap.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "django-app.fullname" . }}-config
  labels:
    {{- include "django-app.labels" . | nindent 4 }}
data:
  DJANGO_ALLOWED_HOSTS: "*"
EOF

# HPA (вкл/викл через values.autoscaling.enabled)
cat > lesson-7/charts/django-app/templates/hpa.yaml <<'EOF'
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "django-app.fullname" . }}
  labels:
    {{- include "django-app.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "django-app.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas | default 2 }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas | default 6 }}
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage | default 70 }}
{{- end }}
EOF

# values.yaml (якщо твій уже є — не чіпай; інакше створимо мінімальний)
cat > lesson-7/charts/django-app/values.yaml <<'EOF'
replicaCount: 2

image:
  repository: ""
  tag: "latest"

service:
  type: LoadBalancer
  port: 80
  targetPort: 8000

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 6
  targetCPUUtilizationPercentage: 70

resources: {}
EOF

# прибрати випадкові CRLF у шаблонах (важливо)
sed -i 's/\r$//' lesson-7/charts/django-app/templates/*.yaml \
                 lesson-7/charts/django-app/templates/_helpers.tpl \
                 lesson-7/charts/django-app/values.yaml
