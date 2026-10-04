import { SiteBanner } from "../banners/SiteBanner";

/**
 * Full-width home welcome banner with animated Haikei layered-wave background.
 */
export function HomeBanner() {
  return (
    <SiteBanner
      variant="home"
      ariaLabel="Welcome"
      eyebrow="John Fraser SAC"
      title={["Welcome back,"]}
      accent="JAGUAR"
    />
  );
}
