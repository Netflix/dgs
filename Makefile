.PHONY: help serve build
.DEFAULT_GOAL := help

SHELL = /bin/sh


#  Docker image ref. https://hub.docker.com/r/squidfunk/mkdocs-material/

serve: ## Start the server on http://localhost:8000
	docker run --rm -it -p 8000:8000 -v ${PWD}:/docs squidfunk/mkdocs-material

build: ## Build documentation
	docker run --rm -it -v ${PWD}:/docs squidfunk/mkdocs-material build

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
