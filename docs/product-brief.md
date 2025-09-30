# Product brief

The "Rate My Portfolio" experience should:

- Run as a Next.js web application.
- Let investors upload one or more documents that describe their portfolio (statements, screenshots, notes).
- Allow the user to specify a risk tolerance: Conservative, Moderate, Aggressive, or Extremely Aggressive.
- Send the documents and risk tolerance to a backend endpoint that prompts an LLM for analysis.
- Return a response with ratings across several axes (risk alignment, growth potential, diversification, etc.), narrative commentary, and recommended improvements.
- Provide a way to share the resulting insights via link sharing or native share sheets.
- Present the journey with an attractive, modern interface.

The build process followed these steps:

1. Investigated the requirements and designed the end-to-end flow.
2. Implemented the interface, API route, and AI prompt scaffolding.
3. Documented configuration and validated the solution with lint checks.
