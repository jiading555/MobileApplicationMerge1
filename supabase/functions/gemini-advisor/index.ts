const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
      'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authorization = request.headers.get('Authorization');
    if (!authorization?.startsWith('Bearer ')) {
      return jsonResponse({ error: 'Authentication required.' }, 401);
    }

    const apiKey = Deno.env.get('GEMINI_API_KEY');
    if (!apiKey) {
      return jsonResponse({ error: 'Gemini API key is not configured.' }, 500);
    }

    const body = await request.json();
    const prompt = body?.prompt;
    if (typeof prompt !== 'string' || prompt.trim().length === 0) {
      return jsonResponse({ error: 'Prompt is required.' }, 400);
    }
    if (prompt.length > 30000) {
      return jsonResponse({ error: 'Prompt is too long.' }, 400);
    }

    const model = Deno.env.get('GEMINI_MODEL') ?? 'gemini-3.5-flash-lite';
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': apiKey,
        },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt.trim() }] }],
          generationConfig: {
            temperature: 0.25,
            maxOutputTokens: 500,
          },
        }),
      },
    );

    const data = await response.json();
    if (!response.ok) {
      const detail =
          data?.error?.message ?? `Gemini request failed (${response.status}).`;
      return jsonResponse({ error: detail }, response.status);
    }

    const text = data?.candidates?.[0]?.content?.parts
        ?.map((part: { text?: string }) => part.text ?? '')
        .join('')
        .trim();

    if (!text) {
      return jsonResponse({ error: 'Gemini returned no content.' }, 502);
    }

    return jsonResponse({ text });
  } catch (error) {
    return jsonResponse(
      { error: error instanceof Error ? error.message : 'Unexpected error.' },
      500,
    );
  }
});

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
}
