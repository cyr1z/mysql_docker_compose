# import config.
# You can change the default config with `make cnf="config_special.env" build`
cnf ?= .env
include $(cnf)
export $(shell sed 's/=.*//' $(cnf))
export DATE=`date '+%d-%m-%Y--%H-%M'`
export LAST_BACKUP_FILE=`ls -1t ./database/backup | head -n 1`

# HELP
# This will output the help for each task
# thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help start build build-nc stop down logs db-logs db-shell db-bash db-dump-restore

help: ## This help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help

# default: build-nc start

# DOCKER TASKS

build: ## Build the container
	docker build -t $(APP_NAME):$(VERSION) -t $(APP_NAME):latest .

build-nc: ## Build the container without caching
	docker build --no-cache -t $(APP_NAME):$(VERSION) -t $(APP_NAME):latest .

start: ## Build the container
	docker-compose --env-file .env up -d

stop: ## Stop and remove a running container
	docker-compose --env-file .env stop

down: ## Stop and remove a running container
	docker-compose --env-file .env down -v

logs: ## view logs
	docker logs $(APP_NAME)

db-logs: ## view database logs
	docker logs mariadb-${APP_NAME}

db-shell: ## database shell
	docker exec -it mariadb-${APP_NAME} sh -c "exec mysql -uroot -p${MYSQL_ROOT_PASSWORD}"

db-bash: ## database bash
	docker exec -it mariadb-${APP_NAME} bash

db-dump: ## Make database dump
	docker exec mariadb-${APP_NAME} sh -c "exec mysqldump --databases ${MYSQL_DATABASE} -uroot -p${MYSQL_ROOT_PASSWORD} > /backup/${MYSQL_DATABASE}.sql"

db-dump-restore: ## database restore from dump archive
	docker exec -i mariadb-${APP_NAME} sh -c 'exec mysql -uroot -p${MYSQL_ROOT_PASSWORD} < /backup/${MYSQL_DATABASE}.sql'

db-dump-archive: ## Make database dump archive
	docker exec mariadb-${APP_NAME} sh -c "exec mysqldump --databases ${MYSQL_DATABASE} -uroot -p${MYSQL_ROOT_PASSWORD} > /backup/${MYSQL_DATABASE}.sql"
	docker exec -i mariadb-${APP_NAME} sh -c "tar --create --xz --file - /backup/${MYSQL_DATABASE}.sql > /backup/${MYSQL_DATABASE}-dump.tar.xz"
	docker exec -i mariadb-${APP_NAME} sh -c "chmod 666  /backup/${MYSQL_DATABASE}-dump.tar.xz"
	docker exec -i mariadb-${APP_NAME} sh -c "exec rm -f /backup/${MYSQL_DATABASE}.sql"

db-backup: ## database backup
	docker exec -i mariadb-${APP_NAME} sh -c "exec mkdir /backup/${DATE}"
	docker exec -i mariadb-${APP_NAME} sh -c "exec mariabackup --backup --target-dir=/backup/${DATE} --user=root --password=${MYSQL_ROOT_PASSWORD}"
	docker exec -i mariadb-${APP_NAME} sh -c "tar --create --xz --file - /backup/${DATE} > /backup/${DATE}-backup.tar.xz"
	docker exec -i mariadb-${APP_NAME} sh -c "chmod 666  /backup/${DATE}-backup.tar.xz"
	docker exec -i mariadb-${APP_NAME} sh -c "exec rm -rf /backup/${DATE}"
