# Thin wrappers around terraform / terragrunt. ENV=dev|prod
ENV ?= dev
TG  ?= terragrunt
MOCK_ENV := env -u AWS_PROFILE -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY -u AWS_SESSION_TOKEN \
            AWS_CONFIG_FILE=/dev/null AWS_SHARED_CREDENTIALS_FILE=/dev/null TG_MOCK_AWS=true

.PHONY: fmt fmt-check validate test mock-plan plan apply clean

fmt: ## Format all HCL
	terraform fmt -recursive modules
	$(TG) hclfmt --terragrunt-working-dir live

fmt-check: ## Fail if anything is unformatted (CI)
	terraform fmt -recursive -check modules
	$(TG) hclfmt --terragrunt-check --terragrunt-working-dir live

validate: ## terraform validate every module (offline)
	@for m in modules/*/; do echo "== $$m"; terraform -chdir=$$m init -backend=false -input=false >/dev/null && terraform -chdir=$$m validate || exit 1; done

test: ## Offline unit tests (mock provider)
	terraform -chdir=modules/ecs-service init -backend=false -input=false >/dev/null
	terraform -chdir=modules/ecs-service test

mock-plan: ## Full plan of ENV with NO AWS account (local state, fake creds, mocked dependency outputs)
	$(MOCK_ENV) $(TG) run-all plan --terragrunt-working-dir live/$(ENV) --terragrunt-non-interactive -lock=false

plan: ## Real plan of ENV against AWS (creates the S3 state bucket on first run)
	$(TG) run-all plan --terragrunt-working-dir live/$(ENV)

apply: ## Real apply of ENV
	$(TG) run-all apply --terragrunt-working-dir live/$(ENV)

clean: ## Remove caches and mock state
	find . -type d \( -name .terragrunt-cache -o -name .terraform \) -prune -exec rm -rf {} +
	rm -rf live/.mock-state
