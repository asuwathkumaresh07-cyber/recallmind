# RecallMind

Turn your own notes into a study plan, quizzes, flashcards, summaries, and other requested study aids.

**[Open the live app](https://asuwathkumaresh07-cyber.github.io/recallmind/)**

**[Download Android APK (1.1.0)](https://github.com/asuwathkumaresh07-cyber/recallmind/releases/download/v1.1.0/RecallMind-1.1.0.apk)**

## Start with your material

![Actual RecallMind workflow: import notes, enter instructions, generate a study set, and take a quiz](docs/images/recallmind-demo.gif)

1. Paste notes or upload a TXT, Markdown, or Word (.docx) document.
2. Write what you want, for example: "Make a five-day study plan, six quiz questions, eight flashcards, and a summary. I have 20 minutes each day."
3. Generate a study set. Open the plan, summary, quiz, flashcards, additional aids, or original source.
4. Complete study sessions, take quizzes, inspect supporting passages, and practice cards using spaced repetition. Your material and progress stay in the local database.

New libraries start empty. No sample cards are automatically inserted. An upgrade removes untouched original starter cards when there is no review history; edited cards and recorded activity are preserved.

## Generation modes

**AI generation** uses your configured OpenAI or Gemini API key. It sends your notes, instructions, output preferences, and numbered source passages to the selected provider. Use it for custom language, difficulty, exam style, focus, explanations, and additional study aids. Keys are held in memory and cleared when the app closes. Configure your provider, model, and key in Settings or Connect AI.

**Source extraction** works without an API key. It creates a reading/recall schedule, source excerpts, fill-in-the-blank quizzes with terms from the notes, and recall flashcards. Instructions control output types, counts, days, and daily minutes. It does not interpret arbitrary language, difficulty, or exam-style requests; this limit is shown in the app. Short sources produce fewer distinct exercises with an explanation rather than repeated filler.

AI response structure, answer indices, counts, prerequisites, and source indices are validated before saving. Source links help learners verify information; structural validation does not establish factual correctness. Live provider requests still require validation with a user's API key.

## What is saved

- Original notes, source filename, instructions, generation method, and generated outputs.
- Study plan completion, quiz attempts and scores, generated flashcards, schedules, and review history.
- Cards generated from a study set appear in My decks, Study session, and the 3D Knowledge map.
- Delete a study set to remove its source, outputs, attempts, and associated generated cards. Existing review history remains as an activity record.

Browser storage and Android app storage are local to that device. Clearing storage removes saved work. Copy study guide exports a readable text version through the clipboard.

## Supported imports

Paste text or import UTF-8/UTF-16LE TXT, Markdown, and text from Word (.docx). Imports are limited to 5 MB and 60,000 characters per set. Split longer sources into chapters. PDF, scanned images, OCR, legacy .doc, and Word images/charts are not supported in this release. Imported material remains editable before generation.

## Run and validate

Requires Flutter 3.47 / Dart 3.13 or a compatible newer SDK.

```sh
flutter pub get
flutter run -d chrome
flutter analyze
flutter test
flutter build web --no-web-resources-cdn --base-href /recallmind/
flutter build apk --release
```

In this workspace, tool/flutter-local.ps1 runs the copied SDK, and tool/test-local.ps1 temporarily selects Windows system SQLite for tests. Android Gradle builds require a complete Flutter SDK; the machine's SDK is C:/Users/Acer/flutter. On Windows, Flutter plugin setup can require Developer Mode for symbolic links.

The APK is signed with the configured development key for installation testing. A Play Store release requires a private production signing configuration. The Android artifact supports Android 7.0 and newer.

## Architecture

| File | Responsibility |
| --- | --- |
| lib/learning_screen.dart | Notes/import workflow, saved sets, study plan, summaries, quiz, source viewer |
| lib/learning_models.dart | Study set persistence and instruction/output preferences |
| lib/learning_service.dart | Source extraction, AI generation, output validation |
| lib/import_service.dart | TXT/Markdown decoding and DOCX text extraction |
| lib/database.dart | SQLite schema, migration, atomic study set/card saves |
| lib/ai_service.dart | OpenAI/Gemini requests and prerequisite/conversation services |
| lib/domain.dart | Card model and hand-coded SM-2 scheduler |
| lib/study_screen.dart | Card review, prerequisite repair, teach-it-back |
| lib/knowledge_map.dart | Interactive perspective-projected concept graph |

For a shared hosted service, provider credentials and rate limits should be handled by an authenticated backend. This version supports user-supplied keys and local storage.

## Deployment and recording

Source lives on main. GitHub Pages serves the compiled build from gh-pages. Build with --base-href /recallmind/, publish build/web to gh-pages, and retain .nojekyll at the deployment root. Updating main alone does not publish a new compiled app.

The web bundle includes SQLite WebAssembly, the Drift worker, CanvasKit, and licensed Roboto fonts. See assets/fonts/LICENSE.txt for the font license.

tool/record-demo.cjs captures the real browser workflow with Chrome and Playwright. tool/make-demo-gif.py turns those frames into the README GIF using Pillow. The recorder currently uses the Playwright path installed on this machine; adjust it on another workstation.
