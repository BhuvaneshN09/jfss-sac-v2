export function AnnouncementTypeBadge({ club }) {
  if (club) {
    return (
      <span className="badge badge--role badge--role-member">
        <span aria-hidden="true">Club announcement</span>
        <span className="sr-only">Type: Club announcement</span>
      </span>
    );
  }

  return (
    <span className="badge badge--role badge--role-sac-admin">
      <span aria-hidden="true">General announcement</span>
      <span className="sr-only">Type: General announcement</span>
    </span>
  );
}
