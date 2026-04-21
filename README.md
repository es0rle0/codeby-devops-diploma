# Podinfo CI/CD Diploma Project

Дипломный проект по курсу DevOps.

Проект демонстрирует полный цикл сборки, тестирования, публикации и доставки приложения Podinfo в Kubernetes с использованием GitHub Actions, Terraform, Helm, мониторинга и логирования.

## Цель проекта

Реализовать production-like CI/CD pipeline для приложения с открытым исходным кодом, развернуть Kubernetes-кластер в облаке, организовать публикацию артефактов, мониторинг и логирование, а также обеспечить доступность приложения через Интернет.

## Используемое приложение

В качестве приложения используется **Podinfo** — лёгкое cloud-native приложение с открытым исходным кодом, которое подходит для демонстрации:
- сборки из исходников
- контейнеризации
- деплоя в Kubernetes
- health checks
- мониторинга и логирования

## Архитектура

Схема проекта:
- GitHub — хранение кода
- GitHub Actions — CI/CD
- GHCR — registry для Docker-образов
- Yandex Cloud — облачная инфраструктура
- Terraform — инфраструктура как код
- k3s — Kubernetes-кластер на виртуальной машине
- Helm — деплой приложения
- Prometheus + Grafana — мониторинг
- Loki + Alloy — логирование

## Структура репозитория

```text
.
├── app/                    # исходники приложения
├── build/                  # Dockerfile и сборка контейнера
├── deploy/
│   ├── helm/podinfo/       # Helm chart приложения
│   ├── k8s/base/           # базовые Kubernetes manifest'ы
│   ├── monitoring/         # monitoring stack и ServiceMonitor
│   └── logging/            # Loki + Alloy
├── infra/
│   └── terraform/
│       ├── bootstrap/      # начальная настройка провайдера
│       ├── envs/prod/      # основная конфигурация инфраструктуры
│       └── modules/        # переиспользуемые модули (зарезервировано)
├── .github/workflows/      # CI/CD workflows
├── docs/                   # документация и заметки
└── README.md
```

## Git flow

Используется упрощённый git-flow:
- `main` — стабильная ветка
- `develop` — интеграционная ветка
- `feature/*` — ветки разработки

Порядок работы:
1. Создать ветку `feature/<name>` от `develop`
2. Внести изменения, закоммитить
3. Открыть Pull Request в `develop`
4. После ревью — merge в `develop`
5. Для релиза — merge `develop` в `main`

## CI pipeline

Workflow `ci` (`.github/workflows/ci.yml`) выполняет:
- checkout кода
- запуск Go tests с coverage
- сборку Docker image (multistage)
- публикацию образа в GHCR

Образы публикуются в:
`ghcr.io/es0rle0/podinfo-diploma`

Используются versioned tags:
- `sha-<commit>` — для каждого коммита
- branch tags — имя ветки
- `latest` — для основной ветки

## CD pipeline

Workflow `cd` (`.github/workflows/cd.yml`) выполняет:
- валидацию Helm chart (`helm lint` + `helm template`)
- ручной deploy через `workflow_dispatch`
- deployment в Kubernetes-кластер в Yandex Cloud через `helm upgrade --install`
- проверку rollout status

Для доступа к кластеру используется секрет `KUBE_CONFIG_B64` (base64-encoded kubeconfig).

## Инфраструктура

Инфраструктура создаётся с помощью Terraform в Yandex Cloud:
- VPC network + subnet
- статический external IP
- Compute VM (preemptible, standard-v3, 2 vCPU / 4 GB)
- автоматическая установка k3s через cloud-init
- S3-compatible backend для Terraform state в Yandex Object Storage

Terraform state хранится в Object Storage (bucket `tfstate-*`).

## Развёртывание инфраструктуры

Предварительные шаги:
1. Установить и настроить `yc` CLI
2. Создать service account с ролями `editor`, `vpc.admin`, `storage.admin`
3. Создать авторизованный ключ для service account
4. Скопировать `terraform.tfvars.example` → `terraform.tfvars` и заполнить значения
5. Скопировать `backend.hcl.example` → `backend.hcl` и указать имя bucket

Применение:

```bash
cd infra/terraform/envs/prod
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

После apply Terraform выведёт внешний IP виртуальной машины.

## Правила внесения изменений в инфраструктуру

1. Изменения вносятся в отдельной ветке `feature/*`
2. Перед apply обязательно выполнить `terraform plan` и проверить diff
3. Изменения, затрагивающие production-ресурсы (VM, сеть, IP), требуют ревью
4. Деструктивные операции (`destroy`, пересоздание VM) выполняются только вручную
5. State хранится удалённо в Object Storage — локальный state не используется

## Развёртывание приложения

Приложение разворачивается Helm chart'ом:

```bash
helm upgrade --install podinfo deploy/helm/podinfo \
  -n podinfo \
  --create-namespace \
  --set image.repository=ghcr.io/es0rle0/podinfo-diploma \
  --set image.tag=<IMAGE_TAG> \
  --set service.type=NodePort
```

Namespace создаётся автоматически через `--create-namespace`. Все ресурсы привязаны к `{{ .Release.Namespace }}`.

## Развёртывание мониторинга

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f deploy/monitoring/kube-prometheus-stack.values.yaml \
  --set grafana.adminPassword=<PASSWORD>

kubectl apply -f deploy/monitoring/podinfo-servicemonitor.yaml
```

Grafana доступна по адресу: `http://<VM_IP>:30080`

## Развёртывание логирования

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install loki grafana/loki \
  -n logging \
  -f deploy/logging/loki.values.yaml

helm upgrade --install alloy grafana/alloy \
  -n logging \
  -f deploy/logging/alloy.values.yaml
```

Логи Podinfo доступны в Grafana → Explore → datasource Loki → запрос `{pod=~"podinfo.*"}`.

## Мониторинг

Используется kube-prometheus-stack:
- Prometheus — сбор метрик
- Grafana — визуализация
- ServiceMonitor — автоматический scrape метрик Podinfo с `/metrics`

## Логирование

Используется:
- Loki — хранение логов (monolithic mode, filesystem storage)
- Alloy — сбор логов со всех подов через файлы `/var/log/pods/`

## Секреты

Секреты не хранятся в репозитории в открытом виде.

Используются:
- GitHub Actions Secrets (`GITHUB_TOKEN`, `KUBE_CONFIG_B64`)
- локальные переменные окружения
- service account keys вне git

Игнорируются через `.gitignore`:
- `env.local.sh`
- `*.tfvars`, `*.tfvars.json`
- `*.pem`, `*.key`

Шаблоны с placeholder'ами хранятся в репозитории как `*.example`.

## Релизный цикл и версионирование

Релизный цикл:
1. Разработка в `feature/*`
2. Слияние в `develop`
3. Слияние в `main`
4. Автоматическая публикация образа в GHCR
5. Ручной deploy через workflow `cd` с указанием image tag

Версионирование:
- по commit SHA (`sha-<hash>`)
- при необходимости — git tags формата `vX.Y.Z`

## Проверка работоспособности

Приложение (замените `<VM_IP>` на внешний IP виртуальной машины):

```bash
curl http://<VM_IP>:30898/
curl http://<VM_IP>:30898/version
curl http://<VM_IP>:30898/healthz
```

Мониторинг:
- Grafana: `http://<VM_IP>:30080`
- Prometheus targets: проверить в Grafana или через `kubectl -n monitoring get servicemonitor`
- Метрики Podinfo: `curl http://<VM_IP>:30898/metrics`

Логирование:
- Grafana → Explore → datasource Loki
- Запрос: `{pod=~"podinfo.*"}`
