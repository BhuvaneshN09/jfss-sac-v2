import { AnimatedLayeredWaves } from "../home/AnimatedLayeredWaves";
import {
  CLUBS_WAVE_LAYERS,
  HOME_WAVE_LAYERS,
} from "../home/animatedLayeredWavesConfig";

/**
 * Shared full-bleed site banner with animated wave background.
 * `home` = Jaguar welcome look; `section` (alias: `clubs`) = rotated dual-wave look.
 */
export function SiteBanner({
  title,
  accent,
  eyebrow,
  description,
  ariaLabel = "Banner",
  variant = "home",
}) {
  const isSection = variant === "section" || variant === "clubs";
  const titleNodes = Array.isArray(title) ? title : [title];

  return (
    <section className="home-banner" aria-label={ariaLabel}>
      <AnimatedLayeredWaves
        backgroundColor="#213659"
        layers={isSection ? CLUBS_WAVE_LAYERS : HOME_WAVE_LAYERS}
        rotation={isSection ? 180 : 0}
      />
      <div className="home-banner__inner">
        <div className="home-banner__copy">
          {eyebrow ? <p className="home-banner__eyebrow">{eyebrow}</p> : null}
          <h1 className="home-banner__title">
            {titleNodes.map((line, index) => (
              <span className="home-banner__line" key={`banner-line-${index}`}>
                {line}
              </span>
            ))}
            {accent ? (
              <span className="home-banner__accent">{accent}</span>
            ) : null}
          </h1>
          {description ? (
            <p className="home-banner__description">{description}</p>
          ) : null}
        </div>
      </div>
    </section>
  );
}
