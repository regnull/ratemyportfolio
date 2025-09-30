# Rate My Portfolio

Rate My Portfolio is a slick Next.js web application that helps investors evaluate how well their holdings align with their risk tolerance. Upload the documents that describe a portfolio, pick a risk profile, and the app will send everything to an AI model that returns ratings, commentary, and improvement ideas that you can share with others.

## Project plan

1. **Discover & design** – Confirm the product requirements, map the primary user flow (upload → choose risk → submit → view/share results), and outline the supporting API and UI components.
2. **Implement the experience** – Bootstrap a Next.js 15 app with Tailwind CSS, build reusable components for uploads, risk selection, results, and sharing, and create an API route that composes an LLM prompt from the uploaded files.
3. **Document & test** – Capture configuration details (environment variables, scripts) in this README and validate the project using the built-in lint command.

## Architecture overview

- **App Router (Next.js 15)** – The UI lives under `app/` using a single-page workflow with client components for interactive controls.
- **Components** – Custom building blocks (`FileUpload`, `RiskToleranceSelector`, `ResultCard`, `ShareButton`) keep the page composed, accessible, and easy to extend.
- **API Route (`app/api/rate`)** – Accepts multipart form data, normalises risk selection, reads the text contents of each file (up to 5 MB, trimmed to 2 000 characters), and calls OpenAI to obtain structured JSON analysis. If no API key is configured, the route returns a deterministic mock analysis so that the front end remains testable.
- **Styling** – Tailwind CSS 4 powers a glassmorphic-inspired design with gradients, rounded surfaces, and high-contrast typography.

## Getting started

### Prerequisites

- Node.js 18.18 or later (Next.js 15 requirement)
- npm 9+ (installed automatically with Node)

### Installation

Install dependencies after cloning the repository:

```bash
npm install
```

### Environment configuration

The portfolio analysis endpoint requires an OpenAI API key. Create a `.env.local` file at the project root and add the key:

```bash
OPENAI_API_KEY=sk-your-key-here
```

When the key is missing the API responds with a helpful mock analysis so the UI can be demonstrated without external services.

### Running the development server

```bash
npm run dev
```

The app will be available at [http://localhost:3000](http://localhost:3000). Uploaded files never leave your browser until you submit the form.

### Building for production

```bash
npm run build
```

Start the production build locally with:

```bash
npm run start
```

### Linting

```bash
npm run lint
```

## Usage tips

1. Upload text-based statements, spreadsheets, or screenshots describing your portfolio (each file must be smaller than 5 MB).
2. Select the risk tolerance that best matches your objectives: Conservative, Moderate, Aggressive, or Extremely Aggressive.
3. Click **Rate my portfolio** to generate insights. The response includes axis-specific ratings and actionable suggestions.
4. Share the results using the Web Share API or copy link fallback.

## Folder structure highlights

- `app/page.tsx` – Main landing page, orchestrates upload, submission, and rendering of results.
- `app/api/rate/route.ts` – Backend route that builds the AI prompt and returns the analysis JSON.
- `components/` – Reusable UI components that keep concerns separated.
- `lib/prompt.ts` – Prompt builder and constants for file processing.

## Future enhancements

- Persist analyses to generate shareable URLs with historical tracking.
- Support deeper document parsing (PDF text extraction, spreadsheet parsing) before calling the LLM.
- Add automated tests for the upload form and API route using Playwright or Vitest.

## License

This project is provided as-is for demonstration purposes.
