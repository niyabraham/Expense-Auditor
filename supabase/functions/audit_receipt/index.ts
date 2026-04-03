import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { merchant, amount, date, location, base64Image, policyText } = await req.json()
    
    // SECURE: This key is safely hidden on Supabase servers!
    const apiKey = Deno.env.get('GROQ_API_KEY')
  
    const prompt = `You are a highly skeptical, Zero-Trust Corporate Finance Investigator for Aetheris. Employees frequently lie, submit fake details, or upload blank/black images to steal money. 
      
      COMPANY POLICY:
      ${policyText}
      
      CLAIM DETAILS (SUBMITTED BY SUSPECT EMPLOYEE):
      Merchant: ${merchant}
      Amount: ${amount} USD
      Claimed Date: ${date}
      Location: ${location}
      
      CRITICAL DIRECTIVE: DO NOT TRUST THE TEXT DETAILS ABOVE. YOU MUST VERIFY EVERYTHING USING ONLY YOUR EYES ON THE UPLOADED IMAGE. 
      
      You MUST output a valid JSON object with EXACTLY these keys in this EXACT order:
      {
        "visual_check": "Describe the pixels of the image. Can you clearly read a merchant name and a price? If the image is solid black, blank, or a random photo, you MUST write exactly 'NO_RECEIPT_FOUND'.",
        "date_check": "Extract the date from the image. If visual_check is 'NO_RECEIPT_FOUND', write 'FAIL'.",
        "math_check": "Is ${amount} strictly greater than the policy limit for ${location}? Write 'YES' or 'NO'.",
        "policy_snippet": "Extract the verbatim sentence from the policy justifying the decision. Output 'N/A' if the image is blank.",
        "reason": "Write a 1-sentence summary of why this passed or failed.",
        "status": "approved, flagged, or rejected"
      }
      
      ABSOLUTE OVERRIDES:
      - If visual_check contains 'NO_RECEIPT_FOUND', the status MUST be "rejected". Do not trust the employee's input.
      - If math_check is 'YES', the status MUST be "rejected".`
  
    const groqResponse = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: "meta-llama/llama-4-scout-17b-16e-instruct",
        messages: [{ role: "user", content: [ { type: "text", text: prompt }, { type: "image_url", image_url: { url: `data:image/jpeg;base64,${base64Image}` } } ] }],
        response_format: { type: "json_object" }
      })
    })
  
    const data = await groqResponse.json()
    return new Response(JSON.stringify(data), { headers: { ...corsHeaders, "Content-Type": "application/json" } })
  } catch (err) {
    return new Response(String(err), { status: 500, headers: corsHeaders })
  }
})
