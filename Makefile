BIN := bin/aroli
LDFLAGS := -s -w -X main.version=v$(shell tr -d '[:space:]' < VERSION)

.PHONY: build test smoke install-cli clean

build:
	go build -ldflags '$(LDFLAGS)' -o $(BIN) ./cmd/aroli

test:
	go test ./...

smoke:
	./scripts/smoke-test.sh

install-cli: build
	install -Dm755 $(BIN) $(HOME)/.local/bin/aroli

clean:
	rm -rf bin
