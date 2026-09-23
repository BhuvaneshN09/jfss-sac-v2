import {
  resolveIncomingGatewayUrl,
  toUpstreamGatewayUrl,
} from "./_paths.js";
import { proxySupabaseRequest } from "./_forward.js";

// Node, not Edge: Edge rejects upload bodies around 1 MB with HTTP 413.
export const config = {
  runtime: "nodejs",
  maxDuration: 60,
};

export default {
  async fetch(request) {
    return proxySupabaseRequest(
      request,
      toUpstreamGatewayUrl(
        resolveIncomingGatewayUrl(request.url, undefined, request.headers),
      ),
    );
  },
};
