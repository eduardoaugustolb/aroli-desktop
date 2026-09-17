BIN := bin/rice
LDFLAGS := -s -w -X main.version=v$(shell tr -d '[:space:]' < VERSION)

.PHONY: build test smoke install-cli clean

build:
	go build -ldflags '$(LDFLAGS)' -o $(BIN) ./cmd/rice

test:
	go test ./...

smoke:
	./scripts/smoke-test.sh

install-cli: build
	install -Dm755 $(BIN) $(HOME)/.local/bin/rice

clean:
	rm -rf bin
