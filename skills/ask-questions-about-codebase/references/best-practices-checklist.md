# Engineering Best Practices Checklist

Use this checklist to evaluate codebase compliance. Generate questions about gaps or unclear implementations.

## Global

### Dependency
- [ ] Always check versions used vs latest remote versions (check remotely on PyPI, GitHub, Google, ...). If we are not using the latest remote version, it's a red flag -> bad product.
- [ ] Always check if the selected dependency/component is stable and mature. If the project has few commits on GitHub, few stars (less than 1k), or has not been updated for over a month, it's a red flag -> bad product.


## Python Projects

### Code Quality
- [ ] Linter configured (`ruff`, `flake8`, or `pylint`)
- [ ] Formatter configured (`ruff format`, `black`, or `yapf`)
- [ ] Type hints present in function signatures
- [ ] Type checker configured (`mypy`, `pyright`, or `basedpyright`)
- [ ] Docstrings on public modules, classes, and functions
- [ ] No `# type: ignore` without explanation

### Dependency Management
- [ ] Modern tooling (`pyproject.toml` with `uv`, `poetry`, or `hatch`)
- [ ] Locked dependencies (`uv.lock`, `poetry.lock`, or pinned versions)
- [ ] Dev dependencies separated from runtime
- [ ] Python version specified (`.python-version`, `pyproject.toml`)

### Testing
- [ ] Test directory structure mirrors source
- [ ] Unit tests present (`tests/unit/` or `tests/`)
- [ ] Integration tests if external dependencies exist
- [ ] Test runner configured (`pytest` preferred)
- [ ] Coverage reporting (`pytest-cov`)
- [ ] Fixtures and factories for test data

### Security
- [ ] No hardcoded secrets (check for API keys, passwords, tokens)
- [ ] `.env.example` provided (not `.env` committed)
- [ ] Secret scanning in CI (`gitleaks`, `detect-secrets`, `trufflehog`)
- [ ] Dependencies audited (`pip-audit`, `safety`)

## Infrastructure as Code (Terraform/OpenTofu)

### Project Structure
- [ ] Root module vs child modules separation
- [ ] `modules/` directory for reusable components
- [ ] Environment separation (`envs/`, workspaces, or branches)
- [ ] Consistent file naming (`main.tf`, `variables.tf`, `outputs.tf`)

### State Management
- [ ] Remote state backend configured (S3, GCS, Azure Blob)
- [ ] State locking enabled (DynamoDB for S3)
- [ ] State encryption at rest
- [ ] No local state in version control (`.gitignore`)

### Variables & Outputs
- [ ] All variables have descriptions
- [ ] Sensitive variables marked `sensitive = true`
- [ ] Default values only when sensible
- [ ] Outputs documented and selective

### Validation & Testing
- [ ] `terraform validate` in CI
- [ ] `terraform fmt -check` in CI
- [ ] Static analysis (`tfsec`, `checkov`, `trivy`, or `terrascan`)
- [ ] Plan output reviewed before apply
- [ ] Automated tests (`terratest`, `tftest`)

### Security
- [ ] No hardcoded credentials in `.tf` files
- [ ] IAM least privilege principle
- [ ] Encryption enabled for storage/databases
- [ ] Network security groups restrictive
- [ ] No `0.0.0.0/0` ingress without justification

### Documentation
- [ ] `README.md` with usage examples
- [ ] Input/output documentation (auto-generated with `terraform-docs`)
- [ ] Architecture diagrams for complex modules

## CI/CD

### Pipeline Basics
- [ ] CI runs on pull requests
- [ ] Linting/formatting checks
- [ ] Tests run automatically
- [ ] Branch protection on main/master

### IaC Pipeline
- [ ] `terraform plan` on PR
- [ ] Plan output visible in PR comments
- [ ] `terraform apply` requires approval
- [ ] Drift detection scheduled

## Local Development

### Environment Setup
- [ ] Setup instructions in `README.md` or `CONTRIBUTING.md`
- [ ] Single command to install dependencies
- [ ] `.env.example` or `direnv` configuration
- [ ] Makefile/justfile for common tasks

### Required Variables Documentation
- [ ] All required env vars listed
- [ ] Purpose of each variable explained
- [ ] Example values provided (non-sensitive)
- [ ] Clear distinction: required vs optional
