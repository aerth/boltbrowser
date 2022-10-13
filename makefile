# uses *existing* go.mod file
# aerth 22
module != go list -m
name != basename ${module}
gofiles != find . -name '*.go'
gopath != go env GOPATH
# long form
VERSION=${name}-$(shell git describe --tags 2>/dev/null)
ifeq (${name}-,$(VERSION))
VERSION=${name}-0.0.1
endif
# commit only
COMMIT=$(shell git rev-parse --verify --short HEAD 2>/dev/null)
ifeq (,$(COMMIT))
COMMIT=none
endif

ldflags ?= -w -s -X main.version=${VERSION} -X main.commit=${COMMIT}
goflags ?= -v -ldflags '$(ldflags)'

ifneq ($(shell ls ./cmd/ 2>/dev/null || true | wc -l), 0)
cmdpath ?= ./cmd/...
else
cmdpath ?= 
endif
buildfunc = go build -o . $(goflags) ${flags} $(1)$(cmdpath)
bin/${name}: go.mod $(gofiles)
	@echo using deps $^
	go list &>/dev/null || printf "package main\n\nvar version string; func main(){\nprintln(version)}" >> main_empty.go
	mkdir -p bin
	cd bin && $(call buildfunc,../)
# cross compile release
crossdirs ?= bin/${name}-linux bin/${name}-freebsd bin/${name}-osx bin/${name}-windows
cross: go.mod $(gofiles)
	mkdir -v -p $(crossdirs) 
	# unroll here if needed
	cd bin/${name}-linux && $(call buildfunc,../../)
	cd bin/${name}-freebsd && GOOS=freebsd $(call buildfunc,../../)
	cd bin/${name}-osx && GOOS=darwin $(call buildfunc,../../)
	cd bin/${name}-windows && GOOS=windows $(call buildfunc,../../)
release: clean cross
	cd bin/ && \
		tar -czf ${name}-linux.tar.gz ${name}-linux && \
		tar -czf ${name}-freebsd.tar.gz ${name}-freebsd && \
		tar -czf ${name}-osx.tar.gz ${name}-osx && \
		zip -r ${name}-windows.zip ${name}-windows && \
		mkdir -p ../release && \
		mv -t ../release/ *.tar.gz *.zip && \
		cd ../release && sha256sum *
help:
	@echo "name:    ${name}"
	@echo "module:  ${module}"
	@echo "gofiles: ${gofiles}"
	@echo "goflags: ${goflags}"
run: bin/$(name)
	test -x bin/$(name)
	$^ &>>debug.log
test:
	go test ${flags} -v ./...
go.mod:
	@echo "run 'go mod init myprojectname'"
	@exit 1
clean:
	${RM} -r bin 
