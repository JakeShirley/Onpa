#!/usr/bin/env node
// Convert semantic-release markdown notes into TestFlight-friendly plain text.
// Reads markdown from stdin (or file argv[2]), writes plain text to stdout (or argv[3]).

const fs = require("fs");

function readInput() {
  const file = process.argv[2];
  if (file && file !== "-") {
    return fs.readFileSync(file, "utf8");
  }
  return fs.readFileSync(0, "utf8");
}

function writeOutput(text) {
  const file = process.argv[3];
  if (file && file !== "-") {
    fs.writeFileSync(file, text);
  } else {
    process.stdout.write(text);
  }
}

function stripMarkdownLinks(line) {
  // [text](url) -> text
  return line.replace(/\[([^\]]+)\]\([^)]*\)/g, "$1");
}

function stripCommitAndIssueTrailers(line) {
  // Drop trailing patterns like "(abcd123)", ", closes #42", "(#42)"
  let result = line;
  // Remove ", closes #N" (and any combinations) until none remain.
  result = result.replace(/,?\s*closes?\s+#\d+(?:,\s*#\d+)*/gi, "");
  // Remove trailing parenthesized short SHA like "(abcd123)" or "(abcd123, def4567)".
  result = result.replace(/\s*\(\s*[0-9a-f]{6,40}(?:\s*,\s*[0-9a-f]{6,40})*\s*\)\s*$/gi, "");
  // Remove trailing parenthesized PR/issue refs like "(#42)".
  result = result.replace(/\s*\(\s*#\d+(?:\s*,\s*#\d+)*\s*\)\s*$/g, "");
  return result;
}

function stripEmphasis(line) {
  // **bold** / __bold__ / *italic* / _italic_ -> bare text
  return line
    .replace(/\*\*([^*]+)\*\*/g, "$1")
    .replace(/__([^_]+)__/g, "$1")
    .replace(/\*([^*]+)\*/g, "$1")
    .replace(/(^|\s)_([^_]+)_(?=\s|$)/g, "$1$2");
}

function stripInlineCode(line) {
  return line.replace(/`([^`]+)`/g, "$1");
}

function convert(markdown) {
  const lines = markdown.split(/\r?\n/);
  const out = [];
  let lastWasBlank = true;
  let firstHeadingSkipped = false;

  for (const raw of lines) {
    let line = raw.trimEnd();

    if (line.length === 0) {
      if (!lastWasBlank) {
        out.push("");
        lastWasBlank = true;
      }
      continue;
    }

    // Skip the leading version heading entirely (e.g. "## [1.2.3](url) (2026-04-27)").
    if (!firstHeadingSkipped && /^#{1,2}\s/.test(line)) {
      firstHeadingSkipped = true;
      continue;
    }

    // Convert subsection headings (### Bug Fixes) into "Bug Fixes:" labels.
    const headingMatch = line.match(/^#{2,6}\s+(.*)$/);
    if (headingMatch) {
      let heading = stripEmphasis(stripInlineCode(stripMarkdownLinks(headingMatch[1]))).trim();
      heading = heading.replace(/[:.]+$/g, "");
      if (heading.length === 0) continue;
      // Add a blank line before headings (unless we just started).
      if (out.length > 0 && out[out.length - 1] !== "") {
        out.push("");
      }
      out.push(`${heading}:`);
      lastWasBlank = false;
      continue;
    }

    // Bullets: "* foo" / "- foo" / "+ foo" -> "• foo".
    const bulletMatch = line.match(/^(\s*)[*\-+]\s+(.*)$/);
    if (bulletMatch) {
      const indent = bulletMatch[1].length >= 2 ? "  " : "";
      let body = bulletMatch[2];
      body = stripMarkdownLinks(body);
      body = stripCommitAndIssueTrailers(body);
      body = stripEmphasis(body);
      body = stripInlineCode(body);
      body = body.replace(/\s{2,}/g, " ").trim();
      if (body.length === 0) continue;
      out.push(`${indent}• ${body}`);
      lastWasBlank = false;
      continue;
    }

    // Plain paragraph line.
    let body = stripMarkdownLinks(line);
    body = stripCommitAndIssueTrailers(body);
    body = stripEmphasis(body);
    body = stripInlineCode(body);
    body = body.replace(/\s{2,}/g, " ").trim();
    if (body.length === 0) continue;
    out.push(body);
    lastWasBlank = false;
  }

  // Trim leading/trailing blank lines and collapse 3+ newlines.
  let result = out.join("\n").replace(/\n{3,}/g, "\n\n").trim();
  return result + "\n";
}

const input = readInput();
writeOutput(convert(input));
