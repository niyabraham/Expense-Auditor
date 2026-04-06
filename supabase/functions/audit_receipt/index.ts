import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { encodeBase64 } from "jsr:@std/encoding/base64";
import { AETHERIS_POLICY } from "./policy.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': Deno.env.get('ALLOWED_ORIGIN') ?? '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { imageUrl, location, date: employeeClaimedDate } = await req.json();
    
    // Server-side fetching to prevent OOM
    console.log("Fetching image from URL: ", imageUrl);
    const imageRes = await fetch(imageUrl);
    const arrayBuffer = await imageRes.arrayBuffer();
    const base64Image = encodeBase64(arrayBuffer);

    // SECURE: This key is safely hidden on Supabase servers!
    const apiKey = Deno.env.get('GROQ_API_KEY');
  
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
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: "llama-3.2-90b-vision-preview",
        messages: [{ role: "user", content: [ { type: "text", text: prompt }, { type: "image_url", image_url: { url: `data:image/jpeg;base64,${base64Image}` } } ] }],
        response_format: { type: "json_object" }
      })
    });
  
    const rawData = await groqResponse.json();
    const content = rawData.choices[0].message.content;
    
    // Robust LLM parsing
    let cleanJson = content;
    const jsonMatch = content.match(/\`\`\`json\s*([\s\S]*?)\s*\`\`\`/);
    if (jsonMatch) {
      cleanJson = jsonMatch[1];
    }
    
    const parsedData = JSON.parse(cleanJson);
    return new Response(JSON.stringify(parsedData), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(String(err), { status: 500, headers: corsHeaders })
  }
})
