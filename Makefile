# ===============================
# Variables
# ===============================

APP_NAME := notes-app
IMAGE_NAME := notes-app
CONTAINER_NAME := notes-container
PORT := 8000

# ===============================
# Help
# ===============================

help:
	@echo "Available Commands:"
	@echo "make install"
	@echo "make update"
	@echo "make build"
	@echo "make run"
	@echo "make stop"
	@echo "make restart"
	@echo "make logs"
	@echo "make shell"
	@echo "make clean"
	@echo "make docker-install"
	@echo "make nginx-install"
	@echo "make git-clone"

# ===============================
# Linux
# ===============================

update:
	sudo apt update

upgrade:
	sudo apt upgrade -y

install:
	sudo apt install git curl unzip vim -y

clean:
	sudo apt autoremove -y
	sudo apt clean

# ===============================
# Git
# ===============================

git-clone:
	git clone https://github.com/USERNAME/REPO.git

git-status:
	git status

git-add:
	git add .

git-commit:
	git commit -m "Updated project"

git-push:
	git push origin main

git-pull:
	git pull origin main

# ===============================
# Docker
# ===============================

docker-install:
	sudo apt install docker.io -y

docker-start:
	sudo systemctl start docker

docker-enable:
	sudo systemctl enable docker

build:
	docker build -t $(IMAGE_NAME) .

run:
	docker run -d -p $(PORT):8000 --name $(CONTAINER_NAME) $(IMAGE_NAME)

stop:
	docker stop $(CONTAINER_NAME)

start:
	docker start $(CONTAINER_NAME)

restart:
	docker restart $(CONTAINER_NAME)

remove-container:
	docker rm -f $(CONTAINER_NAME)

remove-image:
	docker rmi $(IMAGE_NAME)

images:
	docker images

containers:
	docker ps -a

logs:
	docker logs -f $(CONTAINER_NAME)

shell:
	docker exec -it $(CONTAINER_NAME) bash

prune:
	docker system prune -a -f

# ===============================
# Nginx
# ===============================

nginx-install:
	sudo apt install nginx -y

nginx-start:
	sudo systemctl start nginx

nginx-stop:
	sudo systemctl stop nginx

nginx-restart:
	sudo systemctl restart nginx

nginx-status:
	sudo systemctl status nginx

nginx-test:
	sudo nginx -t

# ===============================
# AWS CLI
# ===============================

awscli:
	curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
	unzip -o awscliv2.zip
	sudo ./aws/install
	rm -rf aws awscliv2.zip

# ===============================
# Python
# ===============================

venv:
	python3 -m venv venv

activate:
	. venv/bin/activate

requirements:
	pip install -r requirements.txt

# ===============================
# Django
# ===============================

migrate:
	python manage.py migrate

makemigrations:
	python manage.py makemigrations

runserver:
	python manage.py runserver

createsuperuser:
	python manage.py createsuperuser

collectstatic:
	python manage.py collectstatic --noinput

# ===============================
# Node.js
# ===============================

npm-install:
	npm install

npm-start:
	npm start

npm-build:
	npm run build

npm-dev:
	npm run dev

# ===============================
# Utilities
# ===============================

pwd:
	pwd

list:
	ls -la

disk:
	df -h

memory:
	free -h

cpu:
	lscpu

ip:
	ip a

ports:
	netstat -tulpn