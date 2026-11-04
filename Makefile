.PHONY: all fmt validate lint test docs clean help

# Default target
all: fmt validate lint test

# Format all Terraform files
fmt:
	@echo "==> Formatting Terraform files..."
	terraform fmt -recursive

# Format check (for CI)
fmt-check:
	@echo "==> Checking Terraform formatting..."
	terraform fmt -check -recursive -diff

# Validate all modules and examples
validate:
	@echo "==> Validating Terraform configurations..."
	@for dir in modules/* examples/*; do \
		echo "Validating $$dir..."; \
		(cd $$dir && terraform init -backend=false > /dev/null && terraform validate) || exit 1; \
	done

# Run TFLint
lint:
	@echo "==> Running TFLint..."
	@tflint --init --config "$(PWD)/.tflint.hcl"
	@for dir in modules/* examples/*; do \
		echo "Linting $$dir..."; \
		tflint --chdir="$$dir" --config "$(PWD)/.tflint.hcl" --format=compact || exit 1; \
	done

# Run Checkov security scan
security:
	@echo "==> Running Checkov security scan..."
	checkov -d . --config-file .checkov.yaml

# Run Gitleaks
secrets:
	@echo "==> Running Gitleaks..."
	gitleaks detect --source . -v

# Run Terraform tests
test:
	@echo "==> Running Terraform tests..."
	terraform test

# Generate documentation
docs:
	@echo "==> Generating module documentation..."
	@for dir in modules/*; do \
		echo "Generating docs for $$dir..."; \
		terraform-docs markdown table "$$dir" > "$$dir/README.md" 2>/dev/null || true; \
	done

# Initialize modules for local development
init:
	@echo "==> Initializing modules..."
	@for dir in modules/* examples/*; do \
		echo "Initializing $$dir..."; \
		(cd $$dir && terraform init -backend=false > /dev/null) || true; \
	done

# Deploy complete example
deploy-complete:
	@echo "==> Deploying complete example..."
	@echo "WARNING: This will create AWS resources that incur costs!"
	@read -p "Continue? [y/N] " confirm && [ "$$confirm" = "y" ]
	cd examples/complete && terraform init && terraform apply

# Deploy minimal example
deploy-minimal:
	@echo "==> Deploying minimal example..."
	@echo "WARNING: This will create AWS resources that incur costs!"
	@read -p "Continue? [y/N] " confirm && [ "$$confirm" = "y" ]
	cd examples/minimal && terraform init && terraform apply

# Destroy complete example
destroy-complete:
	@echo "==> Destroying complete example..."
	@echo "WARNING: This will destroy all resources!"
	@read -p "Continue? [y/N] " confirm && [ "$$confirm" = "y" ]
	cd examples/complete && terraform destroy

# Destroy minimal example  
destroy-minimal:
	@echo "==> Destroying minimal example..."
	@echo "WARNING: This will destroy all resources!"
	@read -p "Continue? [y/N] " confirm && [ "$$confirm" = "y" ]
	cd examples/minimal && terraform destroy

# Quick destroy (no confirmation - use with caution!)
destroy:
	@echo "==> Quick destroy (checking for deployed resources)..."
	@if [ -d "examples/complete/.terraform" ]; then \
		echo "Destroying complete example..."; \
		cd examples/complete && terraform destroy -auto-approve; \
	fi
	@if [ -d "examples/minimal/.terraform" ]; then \
		echo "Destroying minimal example..."; \
		cd examples/minimal && terraform destroy -auto-approve; \
	fi
	@echo "Done."

# Clean up generated files
clean:
	@echo "==> Cleaning up..."
	find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.tfstate*" -exec rm -f {} + 2>/dev/null || true
	find . -type f -name ".terraform.lock.hcl" -exec rm -f {} + 2>/dev/null || true
	@echo "Cleaned."

# Run full CI pipeline locally
ci: fmt-check validate lint security test
	@echo "==> All CI checks passed!"

# Help
help:
	@echo "Available targets:"
	@echo "  all             - Run fmt, validate, lint, test"
	@echo "  fmt             - Format Terraform files"
	@echo "  fmt-check       - Check formatting (CI mode)"
	@echo "  validate        - Validate all modules and examples"
	@echo "  lint            - Run TFLint"
	@echo "  security        - Run Checkov security scan"
	@echo "  secrets         - Run Gitleaks"
	@echo "  test            - Run Terraform tests"
	@echo "  docs            - Generate module documentation"
	@echo "  init            - Initialize all modules"
	@echo "  deploy-complete - Deploy complete example"
	@echo "  deploy-minimal  - Deploy minimal example"
	@echo "  destroy-complete- Destroy complete example"
	@echo "  destroy-minimal - Destroy minimal example"
	@echo "  destroy         - Quick destroy all (no confirmation)"
	@echo "  clean           - Clean up generated files"
	@echo "  ci              - Run full CI pipeline locally"
	@echo "  help            - Show this help"
