export function EmptyState({ title, children, action = null }) {
  return (
    <div className="empty-state">
      <h2>{title}</h2>
      {children ? <p>{children}</p> : null}
      {action}
    </div>
  );
}
