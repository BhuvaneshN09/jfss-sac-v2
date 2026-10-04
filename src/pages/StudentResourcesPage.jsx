const guidanceCounsellors = [
  {
    id: "boshra",
    initials: "DB",
    name: "Mr. Boshra",
    range: "Last Names A – D",
    email: "p0205587@pdsb.net",
    bookingUrl: "https://calendar.google.com/calendar/u/0/appointments/schedules/AcZssZ1ew68aBOpw6ny64DMZ_rU4PgdXfcDaAwFVW9dtgYIjM9H2-SQx5YJw4F_MRA8a52YsFJ7x3SYj",
    color: "#2f6fb0",
  },
  {
    id: "parmar",
    initials: "NP",
    name: "Mrs. Parmar",
    range: "Last Names E – K, P",
    email: "p0039995@pdsb.net",
    bookingUrl: "https://calendar.google.com/calendar/u/0/appointments/schedules/AcZssZ1ZYXiMBqSsuzHyy4dSXOAMbVJQlpFyC-KiM3YpJIjJdy5-zrLM_s6qBlGNsvvl-nkG1dsq3P5c",
    color: "#1d4ed8",
  },
  {
    id: "mccomb",
    initials: "LM",
    name: "Ms. McComb",
    range: "Last Names L – O, Y – Z",
    email: "p0070851@pdsb.net",
    bookingUrl: "https://calendar.google.com/calendar/u/0/appointments/schedules/AcZssZ3b5EtKf2TCwezy8X96oyA2NjzsZfjkvM1yxjQDpuVunlrE7374dvqd2bEUdS69ImehcM74KuJW",
    color: "#0b4f6c",
  },
  {
    id: "monteiro",
    initials: "GM",
    name: "Mrs. Monteiro",
    range: "Last Names Q – Z",
    email: "p0074123@pdsb.net",
    bookingUrl: "https://calendar.google.com/calendar/u/0/appointments/schedules/AcZssZ2VmzovX1Yd1_ZA-3zoeiDnkp5X-FHP_Fa58nLx67zefw1VI09rVa-p7GvuIpPkxxCGtngW6pOX",
    color: "#1e3a5f",
  },
];

function BookingArrowIcon() {
  return (
    <svg
      className="counsellor-card__arrow"
      viewBox="0 0 24 24"
      width="1.1rem"
      height="1.1rem"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
    >
      <path d="M7 17 17 7M9 7h8v8" />
    </svg>
  );
}

function CounsellorCard({ counsellor }) {
  return (
    <a
      className="counsellor-card"
      href={counsellor.bookingUrl}
      target="_blank"
      rel="noopener noreferrer"
      aria-label={`Book an appointment with ${counsellor.name}, ${counsellor.range}`}
    >
      <div className="counsellor-card__top">
        <span
          className="counsellor-card__avatar"
          style={{ background: counsellor.color }}
          aria-hidden="true"
        >
          {counsellor.initials}
        </span>
        <span className="counsellor-card__heading">
          <span className="counsellor-card__name">{counsellor.name}</span>
          <span className="counsellor-card__range">{counsellor.range}</span>
        </span>
        <BookingArrowIcon />
      </div>
      <span className="counsellor-card__email">{counsellor.email}</span>
    </a>
  );
}

export function StudentResourcesPage() {
  return (
    <div className="page student-resources-page">
      <section className="panel" aria-labelledby="guidance-counsellors-heading">
        <div className="section-heading">
          <div>
            <p className="eyebrow">Guidance</p>
            <h2 id="guidance-counsellors-heading">Guidance counsellors</h2>
          </div>
        </div>
        <p className="muted counsellor-hint">
          Click a counsellor to book an appointment.
        </p>

        <div className="counsellor-grid">
          {guidanceCounsellors.map((counsellor) => (
            <CounsellorCard key={counsellor.id} counsellor={counsellor} />
          ))}
        </div>
      </section>

      <section className="panel" aria-labelledby="sac-resources-heading">
        <div className="section-heading">
          <div>
            <p className="eyebrow">SAC resources</p>
            <h2 id="sac-resources-heading">Photos and agendas</h2>
          </div>
        </div>
        <div className="quick-links">
          <a
            className="quick-link"
            href="https://drive.google.com/drive/folders/1SMfTaY3obQr5DMAnU3MZMiqWH5JrRxB6"
            target="_blank"
            rel="noopener noreferrer"
          >
            SAC Photos
          </a>
          <a
            className="quick-link"
            href="https://drive.google.com/drive/folders/11pX72a1tGycKR7qWd1HRaj9wGqERGUDs"
            target="_blank"
            rel="noopener noreferrer"
          >
            SAC Agendas
          </a>
        </div>
      </section>
    </div>
  );
}