.PHONY: all
all: docker_containers register_users mix_deps

.PHONY: docker_containers
docker_containers:
	docker-compose up -d

.PHONY: register_users
register_users:
	sleep 20
	docker exec -i -t mim-rmq-mongoose /usr/lib/mongooseim/bin/mongooseimctl register alice localhost alice
	docker exec -i -t mim-rmq-mongoose /usr/lib/mongooseim/bin/mongooseimctl register bob localhost bob

.PHONY: mix_deps
mix_deps:
	cd endpoints; mix deps.get

.PHONY: consumer
consumer:
	cd endpoints; mix run lib/consumer.exs

.PHONY: user
user:
	cd endpoints; mix run lib/user.exs

.PHONY: clean
clean:
	docker-compose down
