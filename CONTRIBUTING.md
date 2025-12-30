# Contributing to ai0-parser

Thank you for your interest in contributing! This project is part of a larger effort to build modern, web-enabled tooling around IDEF0—a methodology with genuine value for system modeling and activity analysis that deserves a healthy, sustainable future.

We welcome:
- Bug reports and fixes
- Feature suggestions and implementations
- Documentation improvements
- Discussion and constructive criticism
- Ideas for the broader IDEF0 tooling ecosystem

## Before You Start

**Please understand**: This project's legal status relative to KBSI's original work and the IDEF0 standard is unclear and potentially contentious. By contributing, you acknowledge:

- You are not claiming ownership of IDEF0, the AI0 format, or KBSI's intellectual property
- KBSI's contributions to IDEF0 are recognized and respected
- This project operates under a placeholder license with all rights reserved pending legal clarification
- Any legal concerns should be raised with the maintainers immediately

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/ai0-parser.git
   cd ai0-parser
   ```
3. **Set up your environment**:
   ```bash
   mix deps.get
   mix escript.build
   ```
4. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Workflow

### Code Style
- Follow Elixir conventions (see [Elixir Style Guide](https://github.com/christopheradams/elixir_style_guide))
- Use meaningful variable and function names
- Add documentation strings (`@doc`, `@spec`) to public functions
- Aim for readability and clarity

### Testing
- Add tests for new functionality
- Ensure existing tests pass:
  ```bash
  mix test
  ```

### Commits
- Write clear, descriptive commit messages
- Reference issues when relevant: `Fixes #123`
- Keep commits focused and atomic

### Documentation
- Update README.md if you change user-facing behavior
- Document new features with examples
- Explain complex parsing logic in comments

## Submitting Changes

1. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Open a Pull Request** on GitHub with:
   - Clear title and description
   - Reference to any related issues
   - Explanation of what changed and why
   - Any breaking changes or new dependencies

3. **Engage in discussion**:
   - Respond to review feedback
   - Be open to suggestions
   - Help refine the contribution together

## Areas for Contribution

### High Priority
- **Format specification**: Document the AI0 text format rules and quirks
- **Unparser**: Implement reverse conversion (JSON/Elixir → TXT)
- **Round-trip validation**: Tests ensuring parse → unparse → parse yield identical results
- **Edge case handling**: Improve robustness for unusual or complex models

### Medium Priority
- **Filtering enhancements**: Additional `--no-*` flags for selective output
- **Error handling**: Better error messages for malformed input
- **Performance**: Optimization for large models
- **Testing infrastructure**: Improved test coverage and fixtures

### Exploratory
- **Format extensions**: Optional enhancements to AI0 format
- **Integration patterns**: How to integrate with other tools
- **Web modeller foundation**: Data structures and APIs for future UI

## Questions and Discussion

- **Unsure about something?** Open a GitHub Discussion
- **Found a bug?** Open an Issue with reproduction steps
- **Have an idea?** Start a Discussion to gather feedback
- **Want to brainstorm?** Engage with the community

## Code of Conduct

This project adheres to a Code of Conduct that prioritizes respect, constructiveness, and acknowledgment of IDEF0's intellectual heritage. Please read [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before participating.

## Licensing and IP

By contributing to this project, you agree that:
- Your contributions are offered under the same placeholder license as the project
- You have the right to contribute the code you're submitting
- You understand the IP uncertainty regarding IDEF0 and KBSI's work

Once the project's license is finalized, all contributions will be governed under that license.

## Recognition

Contributors will be recognized in:
- The project's README contributors section
- Release notes for features they contribute
- The broader IDEF0 community as this project grows

---

**Thank you** for helping build the future of IDEF0 tooling!

Questions? Open a Discussion or contact the maintainers.
