# Airflow Docker Compose Management (ajustado para tu docker-compose.yml)
# ==================================

# Variables
COMPOSE_FILE = docker-compose.yml
PROJECT_NAME = airflow
DOCKER_COMPOSE = docker-compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME)

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

.DEFAULT_GOAL := help

.PHONY: help up down reset init start status logs clean migrate create-user list-users backup restore health shell webserver scheduler dev test prod version restart stop logs-timestamp logs-webserver logs-scheduler logs-worker disk-usage airflow-version ui check-user-variables

help:
	@echo "${GREEN}Airflow Management Commands:${NC}"
	@echo "  ${YELLOW}help${NC}          - Show this help message"
	@echo "  ${YELLOW}up${NC}            - Start Airflow services (detached)"
	@echo "  ${YELLOW}down${NC}          - Stop and remove containers"
	@echo "  ${YELLOW}reset${NC}         - Reset Airflow environment (containers + host dirs)"
	@echo "  ${YELLOW}init${NC}          - Initialize Airflow database (uses airflow-init service)"
	@echo "  ${YELLOW}start${NC}         - Full start (reset + init + up)"
	@echo "  ${YELLOW}status${NC}        - Show container status"
	@echo "  ${YELLOW}logs${NC}          - Show Airflow logs"
	@echo "  ${YELLOW}clean${NC}         - Clean volumes and host data"
	@echo "  ${YELLOW}migrate${NC}       - Run database migrations"
	@echo "  ${YELLOW}create-user${NC}   - Create new Airflow user (uses airflow-cli)"
	@echo "  ${YELLOW}list-users${NC}    - List all Airflow users (uses airflow-cli)"
	@echo "  ${YELLOW}backup${NC}        - Backup Airflow configuration"
	@echo "  ${YELLOW}restore${NC}       - Restore Airflow configuration"

# Basic operations
up:
	@echo "${GREEN}Starting Airflow services (detached)...${NC}"
	$(DOCKER_COMPOSE) up -d
	@echo "${GREEN}Airflow services started successfully!${NC}"

down:
	@echo "${YELLOW}Stopping Airflow services...${NC}"
	$(DOCKER_COMPOSE) down --volumes
	@echo "${GREEN}Airflow services stopped.${NC}"

status:
	@echo "${GREEN}Airflow container status:${NC}"
	$(DOCKER_COMPOSE) ps

logs:
	@echo "${GREEN}Showing Airflow logs... (ctrl+c to exit)${NC}"
	$(DOCKER_COMPOSE) logs -f

# Reset and initialization
reset: down
	@echo "${YELLOW}Resetting Airflow environment (host dirs)...${NC}"
	sudo chown -R $$(id -u):$$(id -g) logs dags plugins || true
	rm -rf logs/* plugins/*
	mkdir -p logs dags plugins
	chmod 777 logs dags plugins
	@echo "${GREEN}Airflow environment reset complete.${NC}"

# Use the dedicated airflow-init service from your compose.
# This service in your docker-compose handles DB migrate / initial user creation.
init: reset
	@echo "${YELLOW}Initializing Airflow database (running airflow-init service)...${NC}"
	# This will start postgres/redis as needed and run the init steps defined in the service.
	$(DOCKER_COMPOSE) up airflow-init
	@echo "${GREEN}Database initialized successfully.${NC}"

start:
	@echo "${YELLOW}Full start: reset -> init -> start services${NC}"
	$(DOCKER_COMPOSE) down --volumes || true
	# Run the dedicated init step which depends on Postgres/Redis
	$(DOCKER_COMPOSE) up airflow-init
	# Start the rest in background
	$(DOCKER_COMPOSE) up -d
	@echo "${GREEN}Airflow started successfully!${NC}"
	@echo "Access Airflow at: http://localhost:8080"

# Database migrations (use airflow-cli; ensure Postgres is reachable)
migrate:
	@echo "${YELLOW}Running database migrations (airflow db upgrade)...${NC}"
	# Ensure DB service is up first (start DB + broker if they aren't running)
	$(DOCKER_COMPOSE) up -d postgres redis
	$(DOCKER_COMPOSE) run --rm airflow-cli airflow db upgrade
	@echo "${GREEN}Database migration completed.${NC}"

# User management
check-user-variables:
	@if [ -z "$(USERNAME)" ] || [ -z "$(PASSWORD)" ] || [ -z "$(EMAIL)" ]; then \
		echo "${RED}Error: Please set USERNAME, PASSWORD, and EMAIL variables (e.g. make create-user USERNAME=admin PASSWORD=secret EMAIL=a@b.com)${NC}"; \
		exit 1; \
	fi

create-user: check-user-variables
	@echo "${YELLOW}Creating new Airflow user (airflow-cli)...${NC}"
	# Ensure services DB/broker are up
	$(DOCKER_COMPOSE) up -d postgres redis
	$(DOCKER_COMPOSE) run --rm airflow-cli \
	  airflow users create \
	    --username $(USERNAME) \
	    --password $(PASSWORD) \
	    --firstname $(FIRSTNAME) \
	    --lastname $(LASTNAME) \
	    --role $(ROLE) \
	    --email $(EMAIL)

list-users:
	@echo "${YELLOW}Listing Airflow users (airflow-cli)...${NC}"
	$(DOCKER_COMPOSE) run --rm airflow-cli airflow users list

# Cleanup and backup
clean:
	@echo "${RED}Cleaning all volumes and host data...${NC}"
	$(DOCKER_COMPOSE) down --volumes --remove-orphans
	rm -rf logs/* plugins/*
	mkdir -p logs dags plugins
	chmod 777 logs dags plugins
	@echo "${GREEN}Clean completed.${NC}"

backup:
	@echo "${YELLOW}Backing up Airflow configuration...${NC}"
	tar -czf airflow-backup-$$(date +%Y%m%d-%H%M%S).tar.gz logs/ dags/ plugins/
	@echo "${GREEN}Backup created: airflow-backup-*.tar.gz${NC}"

restore:
	@echo "${YELLOW}Restoring Airflow configuration...${NC}"
	@echo "${RED}Restore functionality needs to be implemented${NC}"

# Health check
health:
	@echo "${GREEN}Checking Airflow health...${NC}"
	@$(DOCKER_COMPOSE) ps | grep -E "(Up|Exited)" || true
	@echo "${YELLOW}Health check completed.${NC}"

# Debug and development
shell:
	@echo "${YELLOW}Opening shell in airflow-cli container...${NC}"
	$(DOCKER_COMPOSE) exec airflow-cli bash

webserver:
	@echo "${YELLOW}Starting webserver in foreground...${NC}"
	$(DOCKER_COMPOSE) up webserver

scheduler:
	@echo "${YELLOW}Starting scheduler in foreground...${NC}"
	$(DOCKER_COMPOSE) up scheduler

# Environment-specific targets
dev: start
	@echo "${GREEN}Development environment ready!${NC}"

test: reset init up
	@echo "${GREEN}Test environment ready!${NC}"

prod:
	@echo "${YELLOW}Production environment setup...${NC}"
	@echo "${RED}Please configure production settings manually${NC}"

# Utility targets
version:
	@echo "${GREEN}Airflow Makefile Version 1.1 (adjusted)${NC}"
	@echo "Docker Compose File: $(COMPOSE_FILE)"
	@echo "Project Name: $(PROJECT_NAME)"

restart: down up
	@echo "${GREEN}Airflow restarted successfully!${NC}"

stop: down
	@echo "${GREEN}Airflow stopped.${NC}"

# Add a target to get container logs with timestamps
logs-timestamp:
	@echo "${GREEN}Showing Airflow logs with timestamps...${NC}"
	$(DOCKER_COMPOSE) logs --timestamps -f

logs-webserver:
	@echo "${GREEN}Showing webserver logs...${NC}"
	$(DOCKER_COMPOSE) logs webserver -f

logs-scheduler:
	@echo "${GREEN}Showing scheduler logs...${NC}"
	$(DOCKER_COMPOSE) logs scheduler -f

logs-worker:
	@echo "${GREEN}Showing worker logs...${NC}"
	$(DOCKER_COMPOSE) logs worker -f

disk-usage:
	@echo "${GREEN}Checking disk usage for Airflow volumes:${NC}"
	du -sh logs/ dags/ plugins/ 2>/dev/null || echo "No data directories found"

airflow-version:
	@echo "${GREEN}Airflow version:${NC}"
	$(DOCKER_COMPOSE) run --rm airflow-cli airflow version

ui:
	@echo "${GREEN}Access Airflow at: http://localhost:8080${NC}"
	@echo "Default credentials may be set via _AIRFLOW_WWW_USER_USERNAME/_AIRFLOW_WWW_USER_PASSWORD in .env"