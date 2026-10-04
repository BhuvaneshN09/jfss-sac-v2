import { Link } from "react-router-dom";

const CONTACT_EMAIL = "johnfraserstudentcouncil@gmail.com";
const CLUBS_EMAIL = "Johnfrasersupercouncil@gmail.com";
const INSTAGRAM_HANDLE = "johnfrasersac";
const INSTAGRAM_URL = `https://instagram.com/${INSTAGRAM_HANDLE}`;

export function SiteFooter() {
  const year = new Date().getFullYear();

  return (
    <footer className="site-footer">
      <div className="site-footer__inner">
        <Link
          to="/"
          className="site-footer__brand"
          aria-label="John Fraser SAC home"
        >
          <img
            src="/images/SAC-LOGO.png"
            alt="John Fraser SAC"
            className="site-footer__logo"
            width={800}
            height={800}
          />
        </Link>

        <div className="site-footer__lines">
          <p className="site-footer__line site-footer__copy site-footer__copy--full">
            Questions? Shoot us an email at{" "}
            <a href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a> or message{" "}
            <a href={INSTAGRAM_URL} target="_blank" rel="noopener noreferrer">
              @{INSTAGRAM_HANDLE}
            </a>{" "}
            on Instagram.
          </p>
          <p className="site-footer__line site-footer__copy site-footer__copy--short">
            Questions? <a href={`mailto:${CONTACT_EMAIL}`}>Email us</a> or{" "}
            <a href={INSTAGRAM_URL} target="_blank" rel="noopener noreferrer">
              DM @{INSTAGRAM_HANDLE}
            </a>
            .
          </p>

          <p className="site-footer__line site-footer__copy site-footer__copy--full">
            For club inquiries, email{" "}
            <a href={`mailto:${CLUBS_EMAIL}`}>{CLUBS_EMAIL}</a>.
          </p>
          <p className="site-footer__line site-footer__copy site-footer__copy--short">
            Club inquiries? <a href={`mailto:${CLUBS_EMAIL}`}>Email us</a>.
          </p>

          <p className="site-footer__line site-footer__line--meta">
            <span>
              <span className="site-footer__copy site-footer__copy--full">
                &copy; {year} SAC John Fraser
              </span>
              <span className="site-footer__copy site-footer__copy--short">
                &copy; {year} SAC
              </span>
            </span>
            <span>
              <span className="site-footer__copy site-footer__copy--full">
                Made and Maintained By John Fraser Students
              </span>
              <span className="site-footer__copy site-footer__copy--short">
                Made by JF Students
              </span>
            </span>
          </p>
        </div>
      </div>
    </footer>
  );
}
