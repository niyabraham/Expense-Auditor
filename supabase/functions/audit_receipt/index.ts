import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { encodeBase64 } from "jsr:@std/encoding/base64";
import { AETHERIS_POLICY } from "./policy.ts";

// Always allow CORS — ALLOWED_ORIGIN can restrict to a specific domain,
// but we MUST fall back to '*' so the browser never gets a missing header.
const allowedOrigin = Deno.env.get('ALLOWED_ORIGIN') || '*';
const corsHeaders = {
  'Access-Control-Allow-Origin': allowedOrigin,
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function sniffImageMime(bytes: Uint8Array): string | null {
  if (
    bytes.length >= 8 &&
    bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47 &&
    bytes[4] === 0x0d && bytes[5] === 0x0a && bytes[6] === 0x1a && bytes[7] === 0x0a
  ) return "image/png";
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff)
    return "image/jpeg";
  if (
    bytes.length >= 12 &&
    bytes[0] === 0x52 && bytes[1] === 0x49 && bytes[2] === 0x46 && bytes[3] === 0x46 &&
    bytes[8] === 0x57 && bytes[9] === 0x45 && bytes[10] === 0x42 && bytes[11] === 0x50
  ) return "image/webp";
  return null;
}

function isPdfBytes(bytes: Uint8Array): boolean {
  return (
    bytes.length >= 4 &&
    bytes[0] === 0x25 && // %
    bytes[1] === 0x50 && // P
    bytes[2] === 0x44 && // D
    bytes[3] === 0x46    // F
  );
}

/** Decode a single PDF string token — hex <...> or literal (...) form */
function decodePdfString(token: string): string {
  token = token.trim();
  if (token.startsWith("<") && token.endsWith(">")) {
    const hex = token.slice(1, -1).replace(/\s/g, "");
    let result = "";
    for (let i = 0; i < hex.length; i += 2) {
      result += String.fromCharCode(parseInt(hex.slice(i, i + 2), 16));
    }
    return result;
  }
  if (token.startsWith("(") && token.endsWith(")")) {
    return token.slice(1, -1)
      .replace(/\\n/g, "\n").replace(/\\r/g, "\r").replace(/\\t/g, "\t")
      .replace(/\\b/g, "\b").replace(/\\f/g, "\f")
      .replace(/\\\\/g, "\\").replace(/\\\(/g, "(").replace(/\\\)/g, ")")
      .replace(/\\([0-7]{1,3})/g, (_, oct) => String.fromCharCode(parseInt(oct, 8)));
  }
  return token;
}

/** Decode the contents of a TJ array: mix of string tokens and numeric kerning values */
function decodePdfStringArray(arr: string): string {
  const parts: string[] = [];
  const re = /(<[0-9a-fA-F\s]*>|\((?:[^\\)]|\\.)*\))/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(arr)) !== null) parts.push(decodePdfString(m[1]));
  return parts.join("");
}

/**
 * Zero-dependency PDF text extractor — pure Deno, no npm/esm imports.
 *
 * Approach:
 *  1. Decode raw bytes as Latin-1 (PDFs are binary but text ops are ASCII-safe).
 *  2. Decompress FlateDecode content streams using the built-in DecompressionStream API.
 *  3. Collect string arguments from BT...ET text blocks (Tj, TJ, ' operators).
 *
 * Works for digitally-generated PDFs (e-receipts, invoices).
 * Scanned-image PDFs will return near-empty text — handled gracefully downstream.
 */
async function extractPdfText(pdfBytes: Uint8Array): Promise<string> {
  const raw = new TextDecoder("latin1").decode(pdfBytes);
  const streamTexts: string[] = [];

  const streamRe = /stream\r?\n([\s\S]*?)\r?\nendstream/g;
  let m: RegExpExecArray | null;

  while ((m = streamRe.exec(raw)) !== null) {
    const streamBody = m[1];
    const dictSlice = raw.slice(Math.max(0, m.index - 500), m.index);
    const isFlate = /\/FlateDecode/i.test(dictSlice);

    let content: string;
    if (isFlate) {
      try {
        const compressedBytes = new Uint8Array(streamBody.length);
        for (let i = 0; i < streamBody.length; i++) {
          compressedBytes[i] = streamBody.charCodeAt(i) & 0xff;
        }
        // Use Deno's built-in DecompressionStream (no external deps needed)
        const ds = new DecompressionStream("deflate-raw");
        const writer = ds.writable.getWriter();
        const reader = ds.readable.getReader();
        writer.write(compressedBytes);
        writer.close();
        const chunks: Uint8Array[] = [];
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          chunks.push(value);
        }
        const total = chunks.reduce((s, c) => s + c.length, 0);
        const merged = new Uint8Array(total);
        let offset = 0;
        for (const chunk of chunks) { merged.set(chunk, offset); offset += chunk.length; }
        content = new TextDecoder("latin1").decode(merged);
      } catch {
        continue; // skip streams that fail to decompress
      }
    } else {
      content = streamBody;
    }

    if (/\bBT\b/.test(content)) streamTexts.push(content);
  }

  const allText: string[] = [];

  for (const stream of streamTexts) {
    const btRe = /BT\b([\s\S]*?)\bET/g;
    let bt: RegExpExecArray | null;
    while ((bt = btRe.exec(stream)) !== null) {
      const block = bt[1];

      // TJ: [(string) kern (string) ...] TJ
      const tjRe = /\[([\s\S]*?)\]\s*TJ/g;
      let tj: RegExpExecArray | null;
      while ((tj = tjRe.exec(block)) !== null) allText.push(decodePdfStringArray(tj[1]));

      // Tj: (string) Tj  or  <hex> Tj
      const tjSimpleRe = /(\((?:[^\\)]|\\.)*\)|<[0-9a-fA-F]*>)\s*Tj/g;
      let tjs: RegExpExecArray | null;
      while ((tjs = tjSimpleRe.exec(block)) !== null) allText.push(decodePdfString(tjs[1]));

      // ' and " (next-line show-string operators)
      const primeRe = /(\((?:[^\\)]|\\.)*\)|<[0-9a-fA-F]*>)\s*['"]/g;
      let prime: RegExpExecArray | null;
      while ((prime = primeRe.exec(block)) !== null) allText.push(decodePdfString(prime[1]));
    }
  }

  // Fallback: grab any readable parenthesised strings from the raw PDF
  if (allText.length === 0) {
    const fallbackRe = /\(([^)\\\n]{2,80})\)/g;
    let fb: RegExpExecArray | null;
    while ((fb = fallbackRe.exec(raw)) !== null) {
      const s = fb[1].trim();
      if (s.length > 1 && /[a-zA-Z0-9]/.test(s)) allText.push(s);
    }
  }

  return allText.map(s => s.trim()).filter(Boolean).join(" ").replace(/\s{2,}/g, " ").trim();
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { imageUrl, location, date: employeeClaimedDate } = await req.json();
    if (typeof imageUrl !== 'string' || imageUrl.trim().length === 0) {
      return jsonResponse(400, { error: "Missing required field: imageUrl" });
    }

    console.log("Fetching receipt from URL:", imageUrl);
    const receiptRes = await fetch(imageUrl);
    if (!receiptRes.ok) {
      return jsonResponse(400, { error: `Failed to fetch receipt (HTTP ${receiptRes.status})` });
    }

    const arrayBuffer = await receiptRes.arrayBuffer();
    const bytes = new Uint8Array(arrayBuffer);
    const apiKey = Deno.env.get('GROQ_API_KEY');
    const headerMime = (receiptRes.headers.get("content-type") ?? "").split(";")[0].trim().toLowerCase();
    const fileIsPdf = headerMime === "application/pdf" || isPdfBytes(bytes);

    // ── PDF PATH ──────────────────────────────────────────────────────────────
    if (fileIsPdf) {
      console.log("PDF detected — extracting text (zero-dependency)...");
      const pdfText = await extractPdfText(bytes);
      console.log(`Extracted ${pdfText.length} characters from PDF`);

      if (!pdfText || pdfText.trim().length < 15) {
        return new Response(JSON.stringify({
          merchant: "UNKNOWN",
          amount: 0.0,
          date: "N/A",
          receipt_date: "NOT_FOUND",
          date_match: "N/A",
          visual_check: "NO_RECEIPT_FOUND",
          math_check: "NO",
          policy_snippet: "N/A",
          reason: "This PDF appears to be a scanned image with no readable text. Please upload a JPG or PNG photo of the receipt instead.",
          status: "flagged",
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      const pdfPrompt = `You are a highly skeptical Zero-Trust Corporate Finance Investigator for Aetheris.

COMPANY POLICY:
${AETHERIS_POLICY}

CLAIM CONTEXT:
Location: ${location}
Employee-Claimed Expense Date: ${employeeClaimedDate ?? 'Auto-detecting...'}

RECEIPT TEXT EXTRACTED FROM PDF:
---
${pdfText.slice(0, 3000)}
---

DIRECTIVE: Analyze the receipt text. Extract the merchant, amount, and date. Apply the same fraud checks as for an image receipt.

CRITICAL DATE FRAUD CHECK: If the employee provided a claimed date ("${employeeClaimedDate}"), compare it against the date found in the receipt text. If they do NOT match, status MUST be "rejected" and reason MUST mention "Date Mismatch Fraud".

Output a valid JSON object with EXACTLY these keys:
{
  "merchant": "Extracted Merchant Name. If none found, write 'UNKNOWN'.",
  "amount": "Numerical Amount as a float. If not found, write 0.0",
  "date": "Extracted Date (YYYY-MM-DD). If not found, write 'N/A'.",
  "receipt_date": "Exact date found in receipt text. Write 'NOT_FOUND' if missing.",
  "date_match": "Compare receipt date vs claimed date '${employeeClaimedDate}'. Write 'YES', 'NO', or 'N/A'.",
  "visual_check": "Describe the receipt content. If no merchant or price found, write 'NO_RECEIPT_FOUND'.",
  "math_check": "Is the amount strictly greater than the policy limit for ${location}? Write 'YES' or 'NO'.",
  "policy_snippet": "Verbatim sentence from the policy justifying the decision.",
  "reason": "1-sentence summary of why this passed or failed.",
  "status": "approved, flagged, or rejected"
}

ABSOLUTE OVERRIDES:
- If visual_check contains 'NO_RECEIPT_FOUND', status MUST be "rejected".
- If date_match is 'NO', status MUST be "rejected" and reason MUST mention "Date Mismatch Fraud".
- If math_check is 'YES', status MUST be "rejected".`;

      const groqRes = await fetch('https://api.groq.com/openai/v1/chat/completions', {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: "llama-3.3-70b-versatile",
          messages: [{ role: "user", content: pdfPrompt }],
          response_format: { type: "json_object" },
        }),
      });

      const rawData = await groqRes.json();
      if (!groqRes.ok) throw new Error(rawData?.error?.message || `Groq error ${groqRes.status}`);
      const content = rawData?.choices?.[0]?.message?.content;
      if (!content) throw new Error("AI returned empty response for PDF");
      let cleanJson = content;
      const jsonMatch = content.match(/```json\s*([\s\S]*?)\s*```/);
      if (jsonMatch) cleanJson = jsonMatch[1];
      return new Response(cleanJson, { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // ── IMAGE PATH (unchanged) ────────────────────────────────────────────────
    const sniffedMime = sniffImageMime(bytes);
    const mime = headerMime.startsWith("image/") ? headerMime : sniffedMime;

    if (!mime || !mime.startsWith("image/")) {
      return jsonResponse(400, {
        error: "Unsupported receipt format. Please upload a JPG, PNG, WebP, or PDF.",
        details: { contentType: headerMime || "unknown" },
      });
    }

    const base64Image = encodeBase64(arrayBuffer);
    const prompt = `You are a highly skeptical, Zero-Trust Corporate Finance Investigator for Aetheris. Employees frequently lie, submit fake details, or upload blank/black images to steal money. 
      
      COMPANY POLICY:
      ${AETHERIS_POLICY}
      
      CLAIM CONTEXT:
      Location: ${location}
      Employee-Claimed Expense Date: ${employeeClaimedDate ?? 'Auto-detecting...'}
      
      CRITICAL DIRECTIVE: You MUST verify the receipt details using ONLY your eyes on the uploaded image. Extract the Merchant, Amount, and Date from the image.
      
      CRITICAL DATE FRAUD CHECK: If the employee provided a claimed date ("${employeeClaimedDate}"), you must physically read the date printed on the receipt image. If the date on the receipt does NOT match this claimed date, you MUST flag this as "Date Mismatch Fraud". If no claimed date was provided (i.e., "Auto-detecting..."), skip this specific fraud check and only extract the date from the receipt.
      
      You MUST output a valid JSON object with EXACTLY these keys in this EXACT order:
      {
        "merchant": "Extracted Merchant Name from the receipt. If none found, write 'UNKNOWN'.",
        "amount": "Extracted Numerical Amount as a float (e.g. 15.99). If not found, write 0.0",
        "date": "Extracted Date (YYYY-MM-DD). If not found, write 'N/A'.",
        "receipt_date": "The exact date you can visually read printed on the physical receipt. Write 'NOT_FOUND' if unreadable.",
        "date_match": "Compare the receipt date you read against the employee-claimed date '${employeeClaimedDate}'. Write 'YES' if they match, 'NO' if they do not match, or 'N/A' if no claimed date was provided.",
        "visual_check": "Describe the pixels of the image. Can you clearly read a merchant name and a price? If the image is solid black, blank, or a random photo, you MUST write exactly 'NO_RECEIPT_FOUND'.",
        "math_check": "Is the extracted amount strictly greater than the policy limit for ${location}? Write 'YES' or 'NO'.",
        "policy_snippet": "Extract the verbatim sentence from the policy justifying the decision. Output 'N/A' if the image is blank.",
        "reason": "Write a 1-sentence summary of why this passed or failed, mentioning Date Mismatch only if applicable.",
        "status": "approved, flagged, or rejected"
      }
      
      ABSOLUTE OVERRIDES (applied in this order, highest priority first):
      - If visual_check contains 'NO_RECEIPT_FOUND', the status MUST be "rejected". Do not trust the employee's input.
      - If date_match is 'NO', the status MUST be "rejected" and the reason MUST mention "Date Mismatch Fraud".
      - If math_check is 'YES', the status MUST be "rejected".`;

    const groqResponse = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: "meta-llama/llama-4-scout-17b-16e-instruct",
        messages: [{ role: "user", content: [{ type: "text", text: prompt }, { type: "image_url", image_url: { url: `data:${mime};base64,${base64Image}` } }] }],
        response_format: { type: "json_object" },
      }),
    });

    const rawData = await groqResponse.json();
    if (!groqResponse.ok) throw new Error(rawData?.error?.message || `Groq error ${groqResponse.status}`);
    if (!rawData.choices?.length) throw new Error("AI Provider failed to respond");
    const content = rawData?.choices?.[0]?.message?.content;
    if (typeof content !== 'string' || !content.trim()) throw new Error("AI returned malformed content");
    let cleanJson = content;
    const jsonMatch = content.match(/```json\s*([\s\S]*?)\s*```/);
    if (jsonMatch) cleanJson = jsonMatch[1];

    return new Response(JSON.stringify(JSON.parse(cleanJson)), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return jsonResponse(500, { error: message });
  }
})
