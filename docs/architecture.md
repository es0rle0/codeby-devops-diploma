# Архитектура дипломного проекта

## Цель
Реализовать полный цикл CI/CD для приложения Podinfo.

## Технологический стек
- Исходный код приложения: Podinfo (Go)
- VCS: GitHub
- Git flow: main, develop, feature/*
- CI/CD: GitHub Actions
- Registry: GHCR
- Локальная среда: WSL + Docker Desktop + k3d
- Целевое окружение: Kubernetes в облаке
- IaC: Terraform
- Хранение Terraform state: S3-compatible Object Storage
- Деплой приложения: Helm
- Мониторинг: Prometheus + Grafana
- Логирование: Loki + Grafana

## Репозиторий
Монорепозиторий:
- app/ — приложение
- build/ — сборка контейнера
- deploy/ — Kubernetes и Helm
- infra/terraform/ — инфраструктура
- .github/workflows/ — пайплайны

## Релизный процесс
1. feature/* -> develop
2. develop -> main
3. tag vX.Y.Z
4. GitHub Actions собирает образ
5. Образ публикуется в GHCR
6. Выполняется деплой в Kubernetes