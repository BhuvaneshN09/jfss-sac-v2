const TABS = [
  { id: "details", label: "Club Details" },
  { id: "people", label: "People" },
  { id: "announcements", label: "Announcements" },
  { id: "funding", label: "Funding" },
  { id: "events", label: "Events" },
];

export function ClubManageTabs({ activeTab, onChange }) {
  return (
    <nav className="subtabs" aria-label="Club management sections" role="tablist">
      {TABS.map((tab) => {
        const selected = activeTab === tab.id;
        return (
          <button
            key={tab.id}
            type="button"
            role="tab"
            id={`manage-tab-${tab.id}`}
            aria-selected={selected}
            aria-controls={`manage-panel-${tab.id}`}
            tabIndex={selected ? 0 : -1}
            className={selected ? "subtab subtab--active" : "subtab"}
            onClick={() => onChange(tab.id)}
            onKeyDown={(event) => {
              const index = TABS.findIndex((item) => item.id === tab.id);
              if (event.key === "ArrowRight") {
                event.preventDefault();
                const next = TABS[(index + 1) % TABS.length];
                onChange(next.id);
                document.getElementById(`manage-tab-${next.id}`)?.focus();
              } else if (event.key === "ArrowLeft") {
                event.preventDefault();
                const prev = TABS[(index - 1 + TABS.length) % TABS.length];
                onChange(prev.id);
                document.getElementById(`manage-tab-${prev.id}`)?.focus();
              } else if (event.key === "Home") {
                event.preventDefault();
                onChange(TABS[0].id);
                document.getElementById(`manage-tab-${TABS[0].id}`)?.focus();
              } else if (event.key === "End") {
                event.preventDefault();
                const last = TABS[TABS.length - 1];
                onChange(last.id);
                document.getElementById(`manage-tab-${last.id}`)?.focus();
              }
            }}
          >
            {tab.label}
          </button>
        );
      })}
    </nav>
  );
}
