import { useEffect, useState } from "react";
import { NavLink, Outlet, useLocation } from "react-router-dom";
import { SiteBanner } from "../banners/SiteBanner";
import { SiteFooter } from "./SiteFooter";
import { useAuth } from "../../context/AuthContext";
import { resolvePageBanner } from "../../config/pageBanners";
import { getStudentNumberFromEmail } from "../../utils/domain";
import { displayName } from "../../utils/format";
import { rememberAuthReturnTo } from "../../utils/authRedirect";
import { toSameOriginSupabaseUrl } from "../../utils/proxiedSupabaseUrl";

const navLinks = [
  { to: "/clubs", label: "Clubs" },
  { to: "/sports", label: "Sports" },
  { to: "/events", label: "Events" },
  { to: "/student-resources", label: "Student Resources" },
  { to: "/our-team", label: "Our Team" },
];

function getAvatarUrl(profile, user) {
  const raw =
    profile?.avatar_url ||
    user?.user_metadata?.avatar_url ||
    user?.user_metadata?.picture ||
    "";
  return toSameOriginSupabaseUrl(raw) || "";
}

function getInitials(name) {
  const letters = String(name || "")
    .trim()
    .replace(/[^a-zA-Z]/g, "")
    .slice(0, 2)
    .toUpperCase();
  return letters || "?";
}

/** Primary navbar role label from system roles. */
function getNavRoleLabel({ isSacAdmin }) {
  if (isSacAdmin) return "SITE ADMIN";
  return "STUDENT";
}

export function AppShell() {
  const {
    user,
    profile,
    isAuthenticated,
    canAccessExecDashboard,
    isSacAdmin,
  } = useAuth();
  const location = useLocation();
  const { pathname } = location;
  const [menuOpen, setMenuOpen] = useState(false);
  const [navHidden, setNavHidden] = useState(false);
  const [avatarFailed, setAvatarFailed] = useState(false);
  const isHome = pathname === "/" || pathname === "";
  const isLogin = pathname === "/login";
  const pageBanner = isLogin ? null : resolvePageBanner(pathname);

  const name = displayName(profile, user);
  const avatarUrl = getAvatarUrl(profile, user);
  const studentNumber = getStudentNumberFromEmail(
    profile?.email || user?.email,
  );
  const roleLabel = getNavRoleLabel({
    isSacAdmin,
  });
  const roleTone = roleLabel === "STUDENT" ? "student" : "staff";

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- reset avatar fallback when source changes
    setAvatarFailed(false);
  }, [avatarUrl]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- close mobile menu after navigation
    setMenuOpen(false);
  }, [pathname]);

  useEffect(() => {
    if (!menuOpen) return;

    function handleKeyDown(event) {
      if (event.key === "Escape") {
        setMenuOpen(false);
      }
    }

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [menuOpen]);

  useEffect(() => {
    let previousScrollY = window.scrollY;

    function handleScroll() {
      const currentScrollY = window.scrollY;
      const scrollDelta = currentScrollY - previousScrollY;

      if (currentScrollY <= 8 || menuOpen) {
        setNavHidden(false);
      } else if (scrollDelta > 4) {
        setNavHidden(true);
      } else if (scrollDelta < -4) {
        setNavHidden(false);
      }

      previousScrollY = currentScrollY;
    }

    window.addEventListener("scroll", handleScroll, { passive: true });
    return () => window.removeEventListener("scroll", handleScroll);
  }, [menuOpen]);

  return (
    <div className="app-shell">
      <header className={`site-header${navHidden ? " site-header--hidden" : ""}`}>
        <div className="site-header__inner">
          <div className="site-header__slot site-header__slot--left">
            <NavLink
              to="/"
              end
              className={({ isActive }) =>
                isActive ? "brand-logo brand-logo--active" : "brand-logo"
              }
              onClick={() => setMenuOpen(false)}
              aria-label="John Fraser SAC home"
            >
              <img
                src="/images/SAC-LOGO.png"
                alt="John Fraser SAC"
                className="brand-logo__image"
                width={800}
                height={800}
              />
            </NavLink>
          </div>

          <nav
            id="main-navigation"
            className={`main-nav${menuOpen ? " main-nav--open" : ""}`}
            aria-label="Main"
          >
            <ul className="main-nav__links">
              {navLinks.map((link) => (
                <li key={link.to}>
                  <NavLink
                    to={link.to}
                    className={({ isActive }) =>
                      isActive ? "nav-link nav-link--active" : "nav-link"
                    }
                    onClick={() => setMenuOpen(false)}
                  >
                    {link.label}
                  </NavLink>
                </li>
              ))}

              {isAuthenticated ? (
                <li>
                  <NavLink
                    to="/my-requests"
                    className={({ isActive }) =>
                      isActive ? "nav-link nav-link--active" : "nav-link"
                    }
                    onClick={() => setMenuOpen(false)}
                  >
                    My Requests
                  </NavLink>
                </li>
              ) : null}
              {isAuthenticated && canAccessExecDashboard ? (
                <li>
                  <NavLink
                    to="/exec-dashboard"
                    className={({ isActive }) =>
                      isActive ? "nav-link nav-link--active" : "nav-link"
                    }
                    onClick={() => setMenuOpen(false)}
                  >
                    Exec Dashboard
                  </NavLink>
                </li>
              ) : null}
            </ul>
          </nav>

          <div className="site-header__slot site-header__slot--right">
            <button
              type="button"
              className="menu-toggle"
              aria-expanded={menuOpen}
              aria-controls="main-navigation"
              aria-label={menuOpen ? "Close menu" : "Open menu"}
              onClick={() => setMenuOpen((open) => !open)}
            >
              <span className="menu-toggle__bars" aria-hidden="true">
                <span />
                <span />
                <span />
              </span>
            </button>

            {isAuthenticated ? (
              <NavLink
                to="/dashboard"
                className={({ isActive }) =>
                  isActive ? "nav-profile nav-profile--active" : "nav-profile"
                }
                onClick={() => setMenuOpen(false)}
                aria-label={
                  studentNumber
                    ? `${name} profile, ${roleLabel}, student number ${studentNumber}`
                    : `${name} profile, ${roleLabel}`
                }
                title={`${name} · ${roleLabel}`}
              >
                <span className="nav-avatar" aria-hidden="true">
                  {avatarUrl && !avatarFailed ? (
                    <img
                      src={avatarUrl}
                      alt=""
                      className="nav-avatar__image"
                      width={40}
                      height={40}
                      onError={() => setAvatarFailed(true)}
                    />
                  ) : (
                    <span className="nav-avatar__fallback">
                      {getInitials(name)}
                    </span>
                  )}
                </span>
                <span
                  className={`nav-profile__meta nav-profile__meta--${roleTone}`}
                  aria-hidden="true"
                >
                  <span className="nav-profile__student-number">
                    {studentNumber || "\u00a0"}
                  </span>
                  <span className="nav-profile__role">{roleLabel}</span>
                </span>
              </NavLink>
            ) : (
              <NavLink
                to="/login"
                className="nav-link nav-link--login"
                onClick={() => {
                  setMenuOpen(false);
                  rememberAuthReturnTo(
                    `${location.pathname}${location.search}${location.hash}`,
                  );
                }}
              >
                Login
              </NavLink>
            )}
          </div>
        </div>
      </header>

      <main className="site-main">
        {pageBanner ? (
          <SiteBanner
            variant="section"
            ariaLabel={pageBanner.ariaLabel}
            eyebrow={pageBanner.eyebrow}
            title={pageBanner.title}
            description={pageBanner.description}
          />
        ) : null}
        <div
          className={
            isHome ? "site-main__body site-main__body--home" : "site-main__body"
          }
        >
          <Outlet />
        </div>
      </main>

      <SiteFooter />
    </div>
  );
}
