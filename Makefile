.PHONY: up down logs clean restart cleandata fresh

up:
	docker-compose up -d

down:
	docker-compose down

logs:
	docker-compose logs -f

clean:
	docker-compose down -v
	docker system prune -f

restart:
	docker-compose restart

cleandata:
	docker-compose down
	rm -rf data/postgres

fresh: cleandata up
	sleep 5
	./load_imdb_data.sh