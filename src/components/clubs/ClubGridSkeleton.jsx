import { ClubCardSkeleton } from "./ClubCardSkeleton";

export function ClubGridSkeleton({ count = 6 }) {
  return (
    <div
      className="club-grid"
      aria-busy="true"
      aria-label="Loading clubs"
    >
      {Array.from({ length: count }, (_, index) => (
        <ClubCardSkeleton key={`club-skeleton-${index}`} />
      ))}
    </div>
  );
}
