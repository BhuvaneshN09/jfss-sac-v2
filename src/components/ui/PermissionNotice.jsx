export function PermissionNotice({ title = "Permission notice", children }) {
  if (!children) return null;

  return (
    <div className="alert alert--warning" role="status">
      <strong>{title}</strong>
      <div>{children}</div>
    </div>
  );
}
