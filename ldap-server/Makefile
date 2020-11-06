up:
	docker-compose up -d ad-server
	docker-compose exec -T ad-server sh setup-ad/setup.sh
	docker-compose exec -T ad-server bash setup-ad/seed.sh
	docker-compose exec -T ad-server samba -D
	
down:
	docker-compose down
