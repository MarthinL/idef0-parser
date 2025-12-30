# Security Policy

## Reporting Security Vulnerabilities

If you discover a security vulnerability in this project, please **do not** open a public GitHub issue. Instead:

1. **Contact the maintainers privately** through [GitHub's security advisory feature](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
2. **Include details**:
   - Description of the vulnerability
   - Steps to reproduce (if applicable)
   - Potential impact
   - Any proof-of-concept code (use discretion)
3. **Allow time for response** before disclosing publicly

We will:
- Acknowledge receipt within 72 hours
- Assess the severity
- Work toward a fix
- Coordinate disclosure timing

## Security Considerations for This Project

### Scope
This project:
- Parses text file input
- Generates JSON/Elixir data structures
- Currently outputs JSON (no network exposure by default)
- Is designed as a data transformation tool

### Current Limitations
- **No authentication or authorization** (not applicable to current scope)
- **No encryption** (handles text data, not secrets)
- **No API security** (CLI tool, not a service)
- **Input validation**: Relies on Elixir/NimbleParsec's robustness

### What We Need Help With

We are actively exploring and discussing security implications:

- **Input validation strategies**: How should we handle malformed or malicious AI0 files?
- **Size limits**: Should we enforce limits on file size or element counts?
- **Error handling**: How much detail should error messages reveal?
- **Data sanitization**: When generating web output, what sanitization is needed?
- **Dependency security**: How should we manage and verify dependencies?

**Nothing is automatically allowed or restricted.** Security practices are open for discussion and community input.

## For Future Phases

As this project evolves toward a web-based IDEF0 modeller:

- Web application security will become critical
- API security, authentication, authorization will be needed
- Database security (if applicable) must be designed in
- Client-side security for diagram rendering
- CORS, CSRF, XSS protections

These decisions will be made through community discussion as the project matures.

## Current Dependencies

This project depends on:
- **Jason** (JSON encoding/decoding)
- **NimbleParsec** (parsing library)
- **Elixir/OTP** (runtime)

All dependencies are checked and monitored. Security issues in dependencies should be reported via the same private channel.

## Philosophy

Our approach to security is:

1. **Transparent**: We discuss security openly within the community
2. **Inclusive**: We welcome security expertise and perspective
3. **Non-committal**: Lacking expertise ourselves in many areas, we prefer open discussion to false confidence
4. **Graduated response**: Security evolves as the project's scope expands
5. **Community-driven**: Security decisions are made with community input

## Getting Involved

If you have security expertise or concerns:

- **Participate in discussions** about security practices
- **Review code** for security implications
- **Suggest practices** and improvements
- **Help design** security for future phases

---

**Last Updated**: December 30, 2025

Have questions about security? Open a GitHub Discussion.
