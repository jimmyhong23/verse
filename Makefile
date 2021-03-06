default: test

docker:
	cp verse docker/verse
	docker build -t huntprod/verse docker/

verse:
	rm -f verse-*
	./pack $(VERSION) && cp verse-* $@

release:
	@echo "Checking that VERSION was defined in the calling environment"
	@test -n "$(VERSION)"
	@echo "OK.  VERSION=$(VERSION)"
	make verse
	make docker
	docker tag -f huntprod/verse huntprod/verse:$(VERSION)
	docker push huntprod/verse
	docker push huntprod/verse:$(VERSION)

test:
	prove -l t/*.t
check: test

Build: Build.PL
	perl ./Build.PL
manifest: Build
	./Build manifest

clean:
	rm -f verse-* verse

.PHONY: default docker release test check manifest
