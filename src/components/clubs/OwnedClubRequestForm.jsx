/* eslint-disable react-hooks/set-state-in-effect */
import { useEffect, useState } from "react";
import { Select } from "../ui/Select";

/** Club picker for request forms when the user owns more than one club. */
export function OwnedClubRequestForm({ clubs, children }) {
  const [selectedClubId, setSelectedClubId] = useState(clubs[0]?.id || "");

  useEffect(() => {
    if (!clubs.some((club) => club.id === selectedClubId)) {
      setSelectedClubId(clubs[0]?.id || "");
    }
  }, [clubs, selectedClubId]);

  const selectedClub = clubs.find((club) => club.id === selectedClubId) || null;

  if (!selectedClub) return null;

  return (
    <div className="stack">
      {clubs.length > 1 ? (
        <Select
          id="owned-club-request-club"
          label="Club"
          value={selectedClub.id}
          onChange={(event) => setSelectedClubId(event.target.value)}
        >
          {clubs.map((club) => (
            <option key={club.id} value={club.id}>
              {club.name}
            </option>
          ))}
        </Select>
      ) : null}
      {children(selectedClub)}
    </div>
  );
}
