

bin/ins-keycloak-csv-import:
	mkdir -p bin
	sudo docker run --rm -v $$(pwd):/build alpine:3 /build/build/alpine-musl-build.sh
