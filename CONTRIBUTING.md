# Contributing to Enso

Thank you for your interest in contributing to Enso! Every contribution directly impacts this project's survival.

## How to Contribute

### Bug Reports
Open an issue with:
- What you expected to happen
- What actually happened
- Steps to reproduce
- Your environment (OS, agent, model)

### New Pattern Templates
The most impactful contribution: share patterns you've discovered in your workflow.
1. Fork the repo
2. Add your pattern to `memory/examples/`
3. Open a PR with a description of when this pattern is useful

### Research Paper Analyses
Enso is built on research. If you've read a paper relevant to agent memory/evolution:
1. Add an analysis to `docs/research/`
2. Explain what insight applies to Enso
3. Suggest a concrete design change

### Code Contributions
1. Fork the repo
2. Create a branch: `git checkout -b feat/your-feature`
3. Make your changes
4. Ensure all hooks pass
5. Open a PR

## Code Style
- Shell scripts: `shellcheck` clean
- Python: PEP 8, type hints, functions < 50 lines
- Documentation: clear, concise, no filler words

## Philosophy
- **Simple > Complex**: If it can be done in 10 lines, don't use 100
- **Code > Prompts**: Rules that matter should be hooks, not suggestions
- **Real > Perfect**: A working 80% solution beats a beautiful design doc

## License
By contributing, you agree that your contributions will be licensed under MIT.
