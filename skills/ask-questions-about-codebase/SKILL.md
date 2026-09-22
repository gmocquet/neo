---
name: ask-questions-about-codebase
description: Analyze the codebase to generate critical questions that help understand architecture decisions, project structure, application logic, local development setup, and engineering best practices compliance and more. Use this when the user asks to review, critique, or understand a codebase, wants to generate questions about code architecture, or needs to evaluate a project against engineering standards. Specifically designed for Python and Infrastructure as Code (Terraform/OpenTofu) projects.
---

# Ask Questions About Codebase

Generate 5 insightful questions to understand and critique a codebase's decisions, structure, and practices.

## Workflow

1. **Discover project structure** - Map the repository layout
2. **Identify technology stack** - Detect languages, frameworks, IaC tools
3. **Analyze key files** - Review configuration, entry points, and core modules
4. **Generate questions** - One per category below
5. **Generate project scores** - Rate the overall quality of the project codebase based on multiple KPIs (see section Codebase quality KPIs).
6. **Generate project quality summary** - Generate the Pros and Cons table (with icons) that summarizes the key points of the architecture and quality of the project codebase.
7. **Output formatted questions** - Present with context and rationale. Output the analysis into a Markdown file stored at `.data/codebase-questions-{YYYY-MM-DD-HH-MM}`

## Analysis Categories

Analyze the whole project codebase, then use the thinking mode to respond to the following questions

### 1. Documentation & User Onboarding

Is the documentation:
- Clear for a new joiner?
- Listing all requirements needed to run and interact with the project?

Does the project:
- Have helpers to interact with it, like a Makefile or Bash scripts? (for example to init the local stack)

### 2. Technology & Design Patterns
Focus: Why was technology X chosen? What design patterns are used?

Examine:
- Language versions and dependencies (`pyproject.toml`, `requirements.txt`, `setup.py`)
- IaC tool choice (Terraform vs OpenTofu, provider versions)
- Framework selection (FastAPI vs Flask, Django patterns)
- Design patterns (Repository pattern, Factory, Dependency Injection)

### 3. Project Structure
Focus: Why are things grouped this way? What's the module organization logic?

Examine:
- Directory hierarchy and naming conventions
- Module boundaries and separation of concerns
- Terraform/OpenTofu module organization
- Monorepo vs polyrepo decisions
- `src/` layout vs flat structure

### 4. Application Logic
Focus: How does the core business logic flow? What are the key abstractions?

Examine:
- Entry points (`main.py`, `__main__.py`, CLI definitions)
- Core domain models and services
- Data flow and transformations
- State management approach
- Terraform resource relationships and data sources

### 5. Local Development Setup
Focus: What's required to run this locally? How are secrets/env vars handled?

Examine:
- `README.md`, `CONTRIBUTING.md`, `docs/` for setup instructions
- Environment configuration (`.env.example`, `direnv`, `.envrc`)
- Dependency management (`pyproject.toml`, `requirements*.txt`)
- Development tools (`Makefile`, `justfile`, `scripts/`)
- Secret management patterns (no hardcoded secrets, vault references)
- Container setup (`Dockerfile`, `docker-compose.yml`)

### 6. Engineering Best Practices
Focus: Does this comply with Python/IaC standards? See `references/best-practices-checklist.md`.

Examine against checklist:
- Code quality (linting, formatting, type hints)
- Testing (unit, integration, coverage)
- Security (static analysis, secret scanning)
- IaC practices (state management, modules, validation)
- CI/CD configuration

## Question Format

For each question, provide:

```markdown
## [Category]: [Concise Question Title]

**Question**: [The specific question to ask]

**Context**: [What you observed that prompted this question - cite specific files/patterns]

**Why This Matters**: [How the answer impacts understanding or highlights a concern]
```

## Codebase quality KPIs

For each question, provide:

```markdown
## [Category]: [Concise Question Title]

**Question**: [The specific question to ask]

**Context**: [What you observed that prompted this question - cite specific files/patterns]

**Why This Matters**: [How the answer impacts understanding or highlights a concern]
```

## Example Output

```markdown
## Technology & Design Patterns: Why FastAPI over Flask?

**Question**: What drove the decision to use FastAPI with Pydantic models instead of Flask for the API layer?

**Context**: The project uses FastAPI (`src/api/`) with extensive Pydantic models in `src/models/`. The async endpoints suggest performance considerations, but the database layer uses synchronous SQLAlchemy.

**Why This Matters**: Understanding this choice clarifies whether async is fully leveraged or if there are blocking I/O concerns to address.
```

## Constraints

- Generate exactly 5 questions (one per category)
- Reference specific files/patterns discovered
- Questions should be open-ended, not yes/no
- Focus on understanding decisions, not criticizing them
- Prioritize questions that would help onboard a new developer
- If something is purely made for testing, ask a question about how we can manage it if we are in production (at scale)
