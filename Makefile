BIN := bin/rice
LDFLAGS := -s -w -X main.version=v$(shell tr -d '[:space:]' < VERSION)

.PHONY: build test install-cli clean

build:
	go build -ldflags '$(LDFLAGS)' -o $(BIN) ./cmd/rice

test:
	go test ./...

install-cli: build
	install -Dm755 $(BIN) $(HOME)/.local/bin/rice

clean:
	rm -rf bin
