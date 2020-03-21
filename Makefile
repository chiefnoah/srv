NAME := srv
VERSION := $(shell git describe --tags --exact-match 2>/dev/null || \
			 printf %s\\n "git-$$(git describe --always --dirty)")

GO_LDFLAGS=-ldflags "-s -w"

.PHONY: build
build: clean $(NAME)

# a temporary version file is created from a template in order to inject the VERSION variable into the static build
# embedding the version into the binary's DWARF table doesn't work because its stripped during the release build
TMP_VERSION_FILE := $(shell tr -dc 'a-f0-9' < /dev/urandom | dd bs=1 count=8 2>/dev/null).go
$(NAME): main.go
	sed 's/MAKE_VERSION/$(VERSION)/' .version > $(TMP_VERSION_FILE)
	go build -o $(NAME) $(GO_LDFLAGS) .; rm $(TMP_VERSION_FILE)

.PHONY: clean
clean:
	rm -f $(NAME)
	rm -rf release


# release static crossbuilds

GO_LDFLAGS_STATIC=-tags netgo -ldflags "-s -w -extldflags -static"

define buildrelease
sed 's/MAKE_VERSION/$(VERSION)/' .version > $(TMP_VERSION_FILE);
GOOS=$(1) GOARCH=$(2) go build -a \
	 -o release/$(NAME)-$(1)-$(2) \
	 $(GO_LDFLAGS_STATIC) . ;
upx -9 release/$(NAME)-$(1)-$(2);
sha512sum release/$(NAME)-$(1)-$(2) > release/$(NAME)-$(1)-$(2).sha512sum;
rm $(TMP_VERSION_FILE);
endef

GOOSARCHES = linux/arm linux/arm64 linux/amd64 darwin/amd64 openbsd/amd64 freebsd/amd64 netbsd/amd64

.PHONY: release
release: main.go
	$(foreach GOOSARCH,$(GOOSARCHES), $(call buildrelease,$(subst /,,$(dir $(GOOSARCH))),$(notdir $(GOOSARCH))))
