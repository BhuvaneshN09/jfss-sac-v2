import { useState } from "react";
import { toOptimizedImageUrl } from "../../utils/optimizedImage";

/**
 * Serves storage images through Vercel Image Optimization at the requested
 * width, falling back to the original URL if optimization is unavailable
 * (for example, when the Hobby transformation quota is used up).
 */
export function OptimizedImage({ src, width, onError, ...props }) {
  const [failedSrc, setFailedSrc] = useState(null);
  const optimizedSrc = toOptimizedImageUrl(src, width);
  const useOriginal = !optimizedSrc || failedSrc === src;

  return (
    <img
      {...props}
      src={useOriginal ? src : optimizedSrc}
      onError={(event) => {
        if (useOriginal) {
          onError?.(event);
          return;
        }
        setFailedSrc(src);
      }}
    />
  );
}
