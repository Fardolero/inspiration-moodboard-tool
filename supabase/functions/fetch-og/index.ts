// Musa — trae la imagen principal (og:image) de cualquier URL pública.
// Deploy: Dashboard de Supabase → Edge Functions → New function → nombrala "fetch-og" → pegar este código → Deploy.
// (o con la CLI: supabase functions deploy fetch-og)

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function extractMeta(html: string, prop: string): string | null {
  const re1 = new RegExp(`<meta[^>]+(?:property|name)=["']${prop}["'][^>]+content=["']([^"']+)["']`, "i");
  const m1 = html.match(re1);
  if (m1) return m1[1];
  const re2 = new RegExp(`<meta[^>]+content=["']([^"']+)["'][^>]+(?:property|name)=["']${prop}["']`, "i");
  const m2 = html.match(re2);
  return m2 ? m2[1] : null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const { url } = await req.json();
    if (!url || typeof url !== "string") throw new Error("Falta la URL");
    const target = new URL(url);
    if (!["http:", "https:"].includes(target.protocol)) throw new Error("URL inválida");

    const res = await fetch(target.toString(), {
      headers: {
        "User-Agent": "Mozilla/5.0 (compatible; MusaLinkPreview/1.0)",
        "Accept": "text/html",
      },
      redirect: "follow",
    });
    if (!res.ok) throw new Error(`No se pudo abrir la página (${res.status})`);

    const html = (await res.text()).slice(0, 400000); // límite de seguridad

    let image = extractMeta(html, "og:image") || extractMeta(html, "twitter:image");
    if (!image) {
      const imgMatch = html.match(/<img[^>]+src=["']([^"']+)["']/i);
      image = imgMatch ? imgMatch[1] : null;
    }
    if (image && !/^https?:\/\//i.test(image)) {
      image = new URL(image, target).toString();
    }

    const titleMeta = extractMeta(html, "og:title");
    const titleTag = (html.match(/<title>([^<]+)<\/title>/i) || [])[1];
    const title = (titleMeta || titleTag || target.hostname).trim();

    if (!image) throw new Error("No se encontró ninguna imagen en esa página");

    return new Response(JSON.stringify({ image, title }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: e instanceof Error ? e.message : "Error desconocido" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
