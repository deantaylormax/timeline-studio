# Timeline Studio: AI Feature List

**This file is an earlier design sketch from 2026-10-24. The README is the current offer.** The $20 tier was dropped. Connecting a model you already use is free. $79 a month applies only when LegalAI runs that same work. Checkout is not in this download. This build is not notarized. Assured Workloads and CJIS are not a promise of this build.

_Last updated: 2026-10-24_

## Pricing tiers

| Tier | Price | What's included |
|---|---|---|
| **Free** | $0 | Full timeline app, open source (AGPL recommended) on GitHub. |
| **Pro** | $20/mo (~$199/yr) | Every AI feature, using the user's own model or API key (OpenAI, Anthropic, or a local model). Data goes only where the user sends it. |
| **Private AI** | $79/mo (~$790/yr) | Same features, zero setup. LegalAI runs open models in a US government-grade GCP Assured Workloads environment. No retention, no training on customer data. Fair-use cap with overage pricing. |

Distribution: one signed and notarized DMG via GitHub Releases or legalai.com. A license key (Paddle or Lemon Squeezy as merchant of record) unlocks Pro and Private AI. Sparkle handles auto-updates. Pro code stays in a private module.

## Recommended models

- **Natural-language timeline editing (tool calling):** gpt-oss 20B or Qwen3 (30B-A3B / 32B). Fits one L4 GPU; runs locally on a strong Mac.
- **Research and data gathering:** Qwen3 235B or gpt-oss 120B on Vertex AI. Bigger models are needed so results aren't made up.
- **Hosting (Private AI tier):** Cloud Run with an NVIDIA L4 GPU inside Assured Workloads. Scale-to-zero, about $0.67/hr for the GPU plus CPU and memory, with an optional warm instance during business hours. Before promising this to prosecutors, confirm GPU instances are covered in the CJIS region.

## Features

### 1. Building timelines
- [ ] Extract dated events from documents (police reports, depositions, emails, medical records, PDFs), with page citations
- [ ] OCR for scanned documents and handwriting
- [ ] Turn an email or text thread into a communication timeline
- [ ] Transcribe audio and video (bodycam, depositions) into timestamped events
- [ ] Research to import: e.g., "Get water-quality testing data for OH, PA, KY, last 5 years." Finds the data, saves it as a CSV in the import format, and loads it into the timeline for editing

### 2. Editing with plain language (spoken or typed)
- [ ] Add, move, merge, split, recolor, relabel events; create tracks ("put all medical events on their own track")
- [ ] Bulk edits ("shift every event from Exhibit 12 by one hour; it was logged in UTC")
- [ ] Preview each change before applying it; full undo

### 3. Analysis
- [ ] Contradiction detection ("Witness A says 9:40, the CAD log says 10:05")
- [ ] Gaps, overlaps, and impossible sequences
- [ ] Map events to legal elements: elements of the offense, statute-of-limitations clocks, deadlines
- [ ] Patterns across many cases

### 4. Questions and answers
- [ ] "What happened between the 911 call and the arrest?" Answered with linked sources
- [ ] "Show me everything Officer Ramirez did." Filters the timeline
- [ ] Every answer cites the source document and page (required)

### 5. Output
- [ ] Narrative summaries (statement of facts, chronology memo, brief section) with citations
- [ ] Trial exhibits and demonstratives (clean, presentation-ready timelines)
- [ ] Deposition outlines built from gaps and contradictions
- [ ] Export to Word, PDF, PowerPoint

### 6. Data cleanup
- [ ] Standardize dates and time zones, remove duplicate events
- [ ] Flag uncertain dates ("sometime in March 2023")
- [ ] Extract people, places, and vehicles into linked profiles

### 7. Trust and compliance
- [ ] Every AI change logged and reversible, with a citation trail
- [ ] Local-only mode for sensitive matters
- [ ] Data-handling policy, no-retention commitment, and DPA for the Private AI tier

### 8. Trial Mode (presentation at trial)
The same chronology used throughout the case, with a contradiction view for closing argument.

- [ ] Split-screen comparison: testimony (quoted, with page and line) on one side; contradicting evidence (text, call log, bodycam frame, GPS point) on the other, both anchored to the same moment on the timeline
- [ ] Contradiction markers: a visual connector between a statement and the evidence that contradicts it (e.g., "I was home all night" at Tr. 142:7 vs. an 11:42 p.m. text from Main St.); one click zooms to full-screen
- [ ] Build-up animation: play the chronology, then reveal contradictions one at a time for closing
- [ ] Layers by witness or theme (e.g., "everything the defendant said vs. what the phone shows"; one witness's inconsistent statements side by side)
- [ ] Courtroom presenter: full-screen, jury-box readable, clicker control; "exhibit-only" view for opening and "with argument" view for closing
- [ ] AI help: auto-flag contradictions across transcripts, texts, and call records; draft a cited closing talking point for each

Court-safe design:
- [ ] **Neutral evidence layer:** only admitted exhibits and testimony, quoted exactly, with no characterization. Usable as a demonstrative during trial
- [ ] **Argument layer:** "Contradiction" labels, emphasis, and the presenting side's interpretation. A separate toggle, used only in closing
- [ ] Every element links back to an exhibit number or transcript cite; export the exact slides for the record

Market note: the defense bar uses contradiction displays heavily too, so the same feature sells to defense attorneys.

## Version 1 priorities
1. Plain-language timeline editing
2. Document-to-events extraction with citations
3. Contradiction and gap detection
4. Narrative export

The research-to-import feature is the headline feature for the $79 Private AI tier. Trial Mode is the main draw for prosecutors and defense attorneys.
