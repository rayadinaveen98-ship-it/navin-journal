# Product brief — v0.1

**Date:** 2026-11-13  
**Status:** Proposed / awaiting visual selection, usability feedback and technical validation

## Product promise

"A private home for your life's stories — beautiful to write, meaningful to revisit, and built to last."

An intimate, premium *pure journaling* product that treats users' words and attachments as irreplaceable. The user owns their archive, can journal offline, and can restore or export their content transparently.

## Jobs to be done

- **Capture:** "Something just happened; let me record it before I forget."
- **Express:** "I need to write freely, without forms or mood prompts stopping me."
- **Organize:** "I want separate journals for different parts of my life."
- **Revisit:** "Show me what I wrote about that day, person, place, or period."
- **Preserve:** "I changed devices; I need everything back without uncertainty."
- **Trust:** "Tell me whether this writing is saved, synced, backed up, and who can read it."

## Users to validate

1. New journaler: wants first-entry success without setup overload.
2. Long-form journaler: wants rich editing, typography, keyboard support.
3. Memory keeper: photos, voice recordings, life periods, recall.
4. Privacy-sensitive user: offline access, backups, encryption, import/export.
5. Multi-device user: phone, tablet and Windows; predictable state and conflict protection.
6. Bilingual user: English + Telugu text, mixed-language search and correct Unicode export.

These are provisional user archetypes, **not validated personas**.

## Scope boundary

**In:** original entries, separate journals, rich text, inline attachments, voice notes/transcripts (where feasible), draft history, browsing, calendar, search, gallery, privacy, verified data recovery, import/export, optional prompts/reminders.

**Not core:** workouts, habits, task/project management, social network/feed, therapy or medical advice, generic AI chatbot, automated writing that overwrites the user's voice.

**Later exploration only:** AI-assisted insight, future letters, Life Chapters, Memory Trails, generated memory books, context-aware suggestions. These must not interfere with P0.

## Experience promise

A new user opens the app, creates a private journal (or uses an optional default), writes one sentence, leaves, and returns to find it intact. A power user can create multiple journals, add media, locate an entry from years ago, and export the archive without learning a complicated system.

## Product metrics (targets to validate, not claims)

- First entry written without creating an account.
- No silent data loss in fault-injection and recovery tests.
- 100% matching entry/media integrity across representative backup/restore fixtures.
- Successful completion of first-write, find-entry, and restore tasks in usability trials.
- No sensitive user content in analytics or crash logs.

## Commercial guardrails

Core local writing and export should remain available without an ongoing subscription. Any paid features need explicit value; recurring fees should correspond to ongoing service costs. No paywall may prevent users from reading or exporting their own archive. Validate costs and pricing before committing.

## Open questions

Which visual direction best supports long-form writing? Which media types are necessary in the first release? What is the minimum cross-platform launch set? What key recovery and optional sync model can be implemented safely without charging unexpectedly?
