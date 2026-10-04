import {
  isAllowedAuthGrant,
  resolveGrantType,
  toUpstreamAuthTokenUrl,
} from "./_paths.js";
import { proxySupabaseRequest } from "./_forward.js";

export const config = { runtime: "edge" };

export default async function handler(request) {
  const incoming = new URL(request.url);
  if (!isAllowedAuthGrant(resolveGrantType(incoming.searchParams))) {
    return new Response(
      JSON.stringify({ message: "Unsupported sign-in method." }),
      {
        status: 400,
        headers: { "content-type": "application/json; charset=utf-8" },
      },
    );
  }

  return proxySupabaseRequest(request, toUpstreamAuthTokenUrl(request.url));
}
