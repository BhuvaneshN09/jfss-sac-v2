import {
  useCallback,
  useEffect,
  useLayoutEffect,
  useRef,
  useState,
} from "react";
import { useAuth } from "../context/AuthContext";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import {
  createAthleteOfTheMonth,
  deleteAthleteOfTheMonth,
  getAthletePhotoUrl,
  getAthletesOfTheMonth,
  canManageAthletesEmail,
  validateAthletePhoto,
} from "../services/athletes";
import { toSameOriginSupabaseUrl } from "../utils/proxiedSupabaseUrl";

const ATHLETE_PLACEHOLDER_COLORS = [
  "#1e2a4a",
  "#2c5eb0",
  "#1a7a5e",
  "#6b3fa0",
  "#b5651d",
];

function getInitials(name) {
  return (
    String(name || "")
      .trim()
      .split(/\s+/)
      .map((part) => part[0])
      .join("")
      .slice(0, 2)
      .toUpperCase() || "?"
  );
}

const sportsTeams = [
  {
    name: "Basketball",
    icon: "🏀",
    description:
      "Fast-paced, competitive, and one of the most popular teams at John Fraser. Tryouts run in the fall for junior and senior squads.",
  },
  {
    name: "Soccer",
    icon: "⚽",
    description:
      "Boys' and girls' teams compete throughout the season with regular practices and league games against other schools.",
  },
  {
    name: "Volleyball",
    icon: "🏐",
    description:
      "A high-energy team sport with junior and senior divisions, known for strong school spirit and a packed gym on game days.",
  },
  {
    name: "Swim",
    icon: "🏊",
    description:
      "Competitive swimmers race in individual and relay events, representing John Fraser at regional and provincial swim meets.",
  },
  {
    name: "Cricket",
    icon: "🏏",
    description:
      "A growing team at John Fraser, cricket brings fierce competition, big personalities, and an electric atmosphere every match day.",
  },
  {
    name: "Tennis",
    icon: "🎾",
    description:
      "Singles and doubles players compete in a fast-paced season, with tryouts open to all skill levels.",
  },
  {
    name: "Badminton",
    icon: "🏸",
    description:
      "One of the school's most competitive teams, with singles and doubles play across multiple skill divisions.",
  },
  {
    name: "Ultimate Frisbee",
    icon: "🥏",
    description:
      "A fast, fun, self-refereed sport built on sportsmanship and teamwork — open to players of any experience level.",
  },
  {
    name: "Rugby",
    icon: "🏉",
    description:
      "A physical, team-first sport that builds toughness and camaraderie through a demanding competitive season.",
  },
  {
    name: "Cross Country",
    icon: "🏃",
    description:
      "Distance runners take on tough courses each fall, building endurance and mental toughness meet after meet.",
  },
  {
    name: "Golf",
    icon: "⛳",
    description:
      "Individual competitors represent John Fraser at regional tournaments throughout the fall season.",
  },
  {
    name: "Table Tennis",
    icon: "🏓",
    description:
      "Quick reflexes and precision define this team, with singles and doubles competition open to all grades.",
  },
];

function AthleteCard({ athlete, index, onRemove }) {
  const photo = toSameOriginSupabaseUrl(
    getAthletePhotoUrl(athlete.photo_storage_path),
  );

  return (
    <div className="athlete-card" data-athlete-card-id={athlete.id}>
      {onRemove ? (
        <button
          type="button"
          className="athlete-card__remove"
          onClick={() => onRemove(athlete)}
          aria-label={`Remove ${athlete.name}`}
        >
          ×
        </button>
      ) : null}
      {photo ? (
        <img
          src={photo}
          alt={athlete.name}
          className="athlete-card__photo"
        />
      ) : (
        <div
          className="athlete-card__photo athlete-card__photo--placeholder"
          style={{
            backgroundColor:
              ATHLETE_PLACEHOLDER_COLORS[index % ATHLETE_PLACEHOLDER_COLORS.length],
          }}
        >
          {getInitials(athlete.name)}
        </div>
      )}
      <h3 className="athlete-card__name">{athlete.name}</h3>
      <p className="athlete-card__sport">{athlete.sport}</p>
    </div>
  );
}

function AddAthleteCard({ onClick }) {
  return (
    <button
      type="button"
      className="athlete-card athlete-card--add"
      onClick={onClick}
      data-add-athlete-card
    >
      <span className="athlete-card__add-icon" aria-hidden="true">
        +
      </span>
    </button>
  );
}

function AthleteEditorCard({ draft, onDraftChange, onCancel, error }) {
  const fileInputRef = useRef(null);
  const [photoPreview, setPhotoPreview] = useState("");
  const [validationError, setValidationError] = useState("");

  useEffect(() => {
    if (!draft.photoFile) {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- reset the local preview when the file is cleared
      setPhotoPreview("");
      return undefined;
    }

    const previewUrl = URL.createObjectURL(draft.photoFile);
    setPhotoPreview(previewUrl);
    return () => URL.revokeObjectURL(previewUrl);
  }, [draft.photoFile]);

  function handlePhotoChange(event) {
    const file = event.target.files?.[0] || null;
    setValidationError(validateAthletePhoto(file) || "");
    onDraftChange({ photoFile: file });
  }

  return (
    <div
      className="athlete-card athlete-card--editor"
      data-athlete-card-id={draft.id}
    >
      <button
        type="button"
        className="athlete-card__remove"
        onClick={onCancel}
        aria-label="Cancel adding athlete"
      >
        ×
      </button>
      <button
        type="button"
        className="athlete-card__photo-button"
        onClick={() => fileInputRef.current?.click()}
        aria-label="Choose athlete image"
      >
        {photoPreview ? (
          <img
            src={photoPreview}
            alt="New athlete preview"
            className="athlete-card__photo"
          />
        ) : (
          <span className="athlete-card__photo athlete-card__photo--placeholder">
            +
          </span>
        )}
      </button>
      <input
        ref={fileInputRef}
        className="file-picker__input"
        type="file"
        accept="image/jpeg,image/png,image/webp"
        onChange={handlePhotoChange}
      />
      <input
        className="input"
        value={draft.name}
        onChange={(event) => onDraftChange({ name: event.target.value })}
        maxLength={120}
        placeholder="Name"
        aria-label="Athlete name"
      />
      <input
        className="input"
        value={draft.sport}
        onChange={(event) => onDraftChange({ sport: event.target.value })}
        maxLength={80}
        placeholder="Sport"
        aria-label="Athlete sport"
      />
      {validationError || error ? (
        <p className="form-error">{validationError || error}</p>
      ) : null}
    </div>
  );
}

function SportCard({ team }) {
  return (
    <div className="sport-card">
      <div className="sport-card__icon" aria-hidden="true">
        {team.icon}
      </div>
      <h3 className="sport-card__name">{team.name}</h3>
      <p className="sport-card__description">{team.description}</p>
    </div>
  );
}

export function SportsPage() {
  const { profile, user } = useAuth();
  const canManageAthletes = canManageAthletesEmail(
    profile?.email || user?.email,
  );
  const [athletes, setAthletes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState("");
  const [saveError, setSaveError] = useState("");
  const [success, setSuccess] = useState("");
  const [saving, setSaving] = useState(false);
  const [pendingRemovals, setPendingRemovals] = useState([]);
  const [drafts, setDrafts] = useState([]);
  const athleteGridRef = useRef(null);
  const pendingAddAnimationRef = useRef(null);
  const pendingRemovalAnimationRef = useRef(null);
  const isAdding = drafts.length > 0;

  const loadAthletes = useCallback(async () => {
    setLoadError("");
    try {
      setAthletes(await getAthletesOfTheMonth());
    } catch (error) {
      setLoadError(error.message || "Could not load Athletes of the Month.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- intentional async public data fetch
    void loadAthletes();
  }, [loadAthletes]);

  async function handleSave() {
    if (
      drafts.some(
        (draft) => !draft.name.trim() || !draft.sport.trim(),
      )
    ) {
      setSaveError("Athlete name and sport are required.");
      return;
    }

    setSaving(true);
    setSaveError("");
    setSuccess("");
    try {
      for (const athleteId of pendingRemovals) {
        const athlete = athletes.find(
          (currentAthlete) => currentAthlete.id === athleteId,
        );
        if (athlete) await deleteAthleteOfTheMonth(athlete);
      }

      const addedAthletes = [];
      for (const [index, draft] of drafts.entries()) {
        const addedAthlete = await createAthleteOfTheMonth({
          userId: user?.id,
          name: draft.name,
          sport: draft.sport,
          photoFile: draft.photoFile,
          displayOrder:
            athletes.length - pendingRemovals.length + index,
        });
        addedAthletes.push(addedAthlete);
      }

      setAthletes((currentAthletes) => [
        ...currentAthletes.filter(
          (athlete) => !pendingRemovals.includes(athlete.id),
        ),
        ...addedAthletes,
      ]);
      setPendingRemovals([]);
      setDrafts([]);
      setSuccess("Changes saved successfully.");
    } catch (error) {
      setSaveError(error.message || "Could not save the changes.");
    } finally {
      setSaving(false);
    }
  }

  function handleRemove(athlete) {
    captureRemovalLayout();
    setPendingRemovals((currentRemovals) => [
      ...currentRemovals,
      athlete.id,
    ]);
    setSaveError("");
    setSuccess("");
  }

  function captureRemovalLayout() {
    pendingRemovalAnimationRef.current = new Map(
      Array.from(
        athleteGridRef.current?.querySelectorAll(
          "[data-athlete-card-id], [data-add-athlete-card]",
        ) || [],
      ).map((card) => [
        card.dataset.athleteCardId || "add-athlete-card",
        card.getBoundingClientRect(),
      ]),
    );
  }

  function handleRemoveDraft(draftId) {
    captureRemovalLayout();
    setDrafts((currentDrafts) =>
      currentDrafts.filter((draft) => draft.id !== draftId),
    );
    setSaveError("");
  }

  function handleCancel() {
    setPendingRemovals([]);
    setDrafts([]);
    setSaveError("");
    setSuccess("");
  }

  function addDraft() {
    const addCard = athleteGridRef.current?.querySelector(
      "[data-add-athlete-card]",
    );
    pendingAddAnimationRef.current = addCard?.getBoundingClientRect() || null;
    setDrafts((currentDrafts) => [
      ...currentDrafts,
      {
        id: crypto.randomUUID(),
        name: "",
        sport: "",
        photoFile: null,
      },
    ]);
    setSaveError("");
    setSuccess("");
  }

  useLayoutEffect(() => {
    const previousRect = pendingAddAnimationRef.current;
    const previousRects = pendingRemovalAnimationRef.current;
    pendingAddAnimationRef.current = null;
    pendingRemovalAnimationRef.current = null;

    if (previousRects) {
      const cards = athleteGridRef.current?.querySelectorAll(
        "[data-athlete-card-id], [data-add-athlete-card]",
      );
      cards?.forEach((card) => {
        const previousCardRect = previousRects.get(
          card.dataset.athleteCardId || "add-athlete-card",
        );
        if (!previousCardRect) return;

        const nextCardRect = card.getBoundingClientRect();
        const offsetX = previousCardRect.left - nextCardRect.left;
        const offsetY = previousCardRect.top - nextCardRect.top;
        if (offsetX === 0 && offsetY === 0) return;

        card.style.transition = "none";
        card.style.transform = `translate(${offsetX}px, ${offsetY}px)`;
        requestAnimationFrame(() => {
          card.style.transition = "transform 0.4s ease";
          card.style.transform = "";
        });
      });
    }

    if (!previousRect) return undefined;

    const addCard = athleteGridRef.current?.querySelector(
      "[data-add-athlete-card]",
    );
    if (!addCard) return undefined;

    const nextRect = addCard.getBoundingClientRect();
    const offsetX = previousRect.left - nextRect.left;
    const offsetY = previousRect.top - nextRect.top;
    if (offsetX === 0 && offsetY === 0) return undefined;

    addCard.style.transition = "none";
    addCard.style.transform = `translate(${offsetX}px, ${offsetY}px)`;
    requestAnimationFrame(() => {
      addCard.style.transition = "transform 0.4s ease";
      addCard.style.transform = "";
    });
    return undefined;
  }, [drafts.length, pendingRemovals.length]);

  if (loading) return <LoadingScreen message="Loading Athletes of the Month…" />;

  return (
    <div className="team-page">
      <div className="team-header">
        <h1 className="team-title">Fraser's Sports Teams</h1>
        <p className="team-subtitle">
          Every competitive team John Fraser has to offer, all in one place.
        </p>
      </div>

      <div className="section-header">
        <h2 className="section-header__title">Athlete of the Month</h2>
        <p className="section-header__subtitle">
          Celebrating standout performances across our teams throughout the year.
        </p>
      </div>

      {loadError ? <ErrorMessage>{loadError}</ErrorMessage> : null}
      {success ? (
        <div className="alert alert--success" role="status">
          {success}
        </div>
      ) : null}
      <div className="athlete-grid" ref={athleteGridRef}>
        {athletes
          .filter((athlete) => !pendingRemovals.includes(athlete.id))
          .map((athlete, index) => (
            <AthleteCard
              key={athlete.id}
              athlete={athlete}
              index={index}
              onRemove={canManageAthletes ? handleRemove : null}
            />
          ))}
        {canManageAthletes ? (
          <>
            {drafts.map((draft) => (
              <AthleteEditorCard
                key={draft.id}
                draft={draft}
                onDraftChange={(changes) =>
                  setDrafts((currentDrafts) =>
                    currentDrafts.map((currentDraft) =>
                      currentDraft.id === draft.id
                        ? { ...currentDraft, ...changes }
                        : currentDraft,
                    ),
                  )
                }
                onCancel={() => handleRemoveDraft(draft.id)}
                error={saveError}
              />
            ))}
            <AddAthleteCard key="add-athlete-card" onClick={addDraft} />
          </>
        ) : null}
      </div>
      {canManageAthletes ? (
        <div className="athlete-editor-actions">
          <button
            className="button button--primary"
            type="button"
            onClick={handleSave}
            disabled={saving || (!isAdding && pendingRemovals.length === 0)}
          >
            {saving ? "Saving…" : "Save changes"}
          </button>
          <button
            className="button button--secondary"
            type="button"
            onClick={handleCancel}
            disabled={saving}
          >
            Cancel
          </button>
        </div>
      ) : null}
      {canManageAthletes && saveError && !isAdding ? (
        <p className="form-error athlete-editor-error">{saveError}</p>
      ) : null}

      <div className="section-header">
        <h2 className="section-header__title">Our Teams</h2>
      </div>

      <div className="sport-grid">
        {sportsTeams.map((team) => (
          <SportCard key={team.name} team={team} />
        ))}
      </div>
    </div>
  );
}