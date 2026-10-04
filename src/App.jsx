import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { GoogleOAuthProvider } from "@react-oauth/google";
import { Analytics } from "@vercel/analytics/react";
import { AuthProvider } from "./context/AuthContext";
import { AuthRedirectProvider } from "./context/AuthRedirectContext";
import { AppShell } from "./components/layout/AppShell";
import { ClubsLayout } from "./components/layout/ClubsLayout";
import { ExecDashboardLayout } from "./components/layout/ExecDashboardLayout";
import { ExecRequestsLayout } from "./components/layout/ExecRequestsLayout";
import { ExecArchivedLayout } from "./components/layout/ExecArchivedLayout";
import { ExecDashboardIndexRedirect } from "./components/layout/ExecDashboardIndexRedirect";
import { ExecRequestsIndexRedirect } from "./components/layout/ExecRequestsIndexRedirect";
import { ExecArchivedIndexRedirect } from "./components/layout/ExecArchivedIndexRedirect";
import { ProtectedRoute } from "./components/auth/ProtectedRoute";
import { RoleRoute } from "./components/auth/RoleRoute";
import { EXEC_DASHBOARD_ROLES } from "./utils/execPermissions";
import { HomePage } from "./pages/HomePage";
import { LoginPage } from "./pages/LoginPage";
import { DashboardPage } from "./pages/DashboardPage";
import { ClubsPage } from "./pages/ClubsPage";
import { ClubDetailPage } from "./pages/ClubDetailPage";
import { ClubManagePage } from "./pages/ClubManagePage";
import { ClubApplyPage } from "./pages/ClubApplyPage";
import { ClubReapplyPage } from "./pages/ClubReapplyPage";
import { MyClubApplicationsPage } from "./pages/MyClubApplicationsPage";
import { MyClubReapplicationsPage } from "./pages/MyClubReapplicationsPage";
import { MySupervisorRequestsPage } from "./pages/MySupervisorRequestsPage";
import { MyFundingRequestsPage } from "./pages/MyFundingRequestsPage";
import { MyEventRequestsPage } from "./pages/MyEventRequestsPage";
import { MyPromoLunchRequestsPage } from "./pages/MyPromoLunchRequestsPage";
import { AdminPromoLunchPage } from "./pages/AdminPromoLunchPage";
import { AdminPromoLunchDetailPage } from "./pages/AdminPromoLunchDetailPage";
import { MyClubsPage } from "./pages/MyClubsPage";
import { MyRequestsLayout } from "./components/layout/MyRequestsLayout";
import { MyClubRequestsLayout } from "./components/layout/MyClubRequestsLayout";
import { MyRequestsIndexRedirect } from "./components/layout/MyRequestsIndexRedirect";
import { AdminClubRequestsPage } from "./pages/AdminClubRequestsPage";
import { AdminClubRequestDetailPage } from "./pages/AdminClubRequestDetailPage";
import { AdminClubReapplicationsPage } from "./pages/AdminClubReapplicationsPage";
import { AdminClubReapplicationDetailPage } from "./pages/AdminClubReapplicationDetailPage";
import { AdminArchivedClubsPage } from "./pages/AdminArchivedClubsPage";
import { AdminArchivedAnnouncementsPage } from "./pages/AdminArchivedAnnouncementsPage";
import { AdminSupervisorRequestsPage } from "./pages/AdminSupervisorRequestsPage";
import { AdminClubSupervisorRequestsDetailPage } from "./pages/AdminClubSupervisorRequestsDetailPage";
import { AdminFundingPlaceholderPage } from "./pages/AdminFundingPlaceholderPage";
import { AdminClubFundingDetailPage } from "./pages/AdminClubFundingDetailPage";
import { AdminEventsPage } from "./pages/AdminEventsPage";
import { AdminClubEventDetailPage } from "./pages/AdminClubEventDetailPage";
import { AdminClubAnnouncementsDetailPage } from "./pages/AdminClubAnnouncementsDetailPage";
import { AdminSchoolDayPage } from "./pages/AdminSchoolDayPage";
import { AnnouncementsPage } from "./pages/AnnouncementsPage";
import { CreateAnnouncementPage } from "./pages/CreateAnnouncementPage";
import { EditAnnouncementPage } from "./pages/EditAnnouncementPage";
import { MyAnnouncementsPage } from "./pages/MyAnnouncementsPage";
import { AdminAnnouncementsPage } from "./pages/AdminAnnouncementsPage";
import { SportsPage } from "./pages/SportsPage";
import { StudentResourcesPage } from "./pages/StudentResourcesPage";
import { NotFoundPage } from "./pages/NotFoundPage";
import { OurTeamPage } from "./pages/OurTeamPage";
import { EventsPage } from "./pages/EventsPage";
import { CurrentEventsPage } from "./pages/CurrentEventsPage";

const GOOGLE_CLIENT_ID = import.meta.env.VITE_GOOGLE_CLIENT_ID;

function AppProviders({ children }) {
  if (!GOOGLE_CLIENT_ID) {
    return children;
  }

  return (
    <GoogleOAuthProvider clientId={GOOGLE_CLIENT_ID}>
      {children}
    </GoogleOAuthProvider>
  );
}

export default function App() {
  return (
    <AppProviders>
      <AuthProvider>
        <BrowserRouter>
          <AuthRedirectProvider>
          <Routes>
          <Route element={<AppShell />}>
            <Route index element={<HomePage />} />
            <Route path="login" element={<LoginPage />} />

            <Route path="clubs" element={<ClubsLayout />}>
              <Route index element={<ClubsPage />} />
              <Route
                path="my-clubs"
                element={
                  <ProtectedRoute>
                    <MyClubsPage />
                  </ProtectedRoute>
                }
              />
              <Route
                path="apply"
                element={
                  <ProtectedRoute>
                    <ClubApplyPage />
                  </ProtectedRoute>
                }
              />
              <Route
                path="reapply"
                element={
                  <ProtectedRoute>
                    <ClubReapplyPage />
                  </ProtectedRoute>
                }
              />
              <Route
                path="register"
                element={<Navigate to="/clubs/apply" replace />}
              />
              <Route path=":slug" element={<ClubDetailPage />} />
              <Route
                path=":slug/manage"
                element={
                  <ProtectedRoute>
                    <ClubManagePage />
                  </ProtectedRoute>
                }
              />
            </Route>

            <Route path="sports" element={<SportsPage />} />
            <Route path="events" element={<CurrentEventsPage />} />
            <Route path="sac-events" element={<EventsPage />} />
            <Route path="student-resources" element={<StudentResourcesPage />} />
            <Route path="our-team" element={<OurTeamPage />} />

            <Route path="announcements" element={<AnnouncementsPage />} />
            <Route
              path="announcements/new"
              element={
                <ProtectedRoute>
                  <CreateAnnouncementPage />
                </ProtectedRoute>
              }
            />
            <Route
              path="announcements/:id/edit"
              element={
                <ProtectedRoute>
                  <EditAnnouncementPage />
                </ProtectedRoute>
              }
            />
            <Route
              path="my-announcements"
              element={
                <Navigate to="/my-requests/announcements" replace />
              }
            />

            <Route
              path="dashboard"
              element={
                <ProtectedRoute>
                  <DashboardPage />
                </ProtectedRoute>
              }
            />

            <Route
              path="my-requests"
              element={
                <ProtectedRoute>
                  <MyRequestsLayout />
                </ProtectedRoute>
              }
            >
              <Route index element={<MyRequestsIndexRedirect />} />
              <Route path="club-requests" element={<MyClubRequestsLayout />}>
                <Route index element={<Navigate to="applications" replace />} />
                <Route path="applications" element={<MyClubApplicationsPage />} />
                <Route
                  path="reapplications"
                  element={<MyClubReapplicationsPage />}
                />
              </Route>
              <Route
                path="applications"
                element={<Navigate to="/my-requests/club-requests/applications" replace />}
              />
              <Route
                path="reapplications"
                element={
                  <Navigate to="/my-requests/club-requests/reapplications" replace />
                }
              />
              <Route
                path="announcements"
                element={<MyAnnouncementsPage embedded />}
              />
              <Route
                path="supervisor"
                element={<MySupervisorRequestsPage />}
              />
              <Route path="funding" element={<MyFundingRequestsPage />} />
              <Route path="events" element={<MyEventRequestsPage />} />
              <Route
                path="promo-lunch"
                element={<MyPromoLunchRequestsPage />}
              />
            </Route>

            <Route
              path="exec-dashboard"
              element={
                <ProtectedRoute>
                  <RoleRoute allowedRoles={EXEC_DASHBOARD_ROLES}>
                    <ExecDashboardLayout />
                  </RoleRoute>
                </ProtectedRoute>
              }
            >
              <Route index element={<ExecDashboardIndexRedirect />} />

              <Route
                path="applications"
                element={
                  <Navigate to="/exec-dashboard/applications/new" replace />
                }
              />
              <Route
                path="applications/new"
                element={<AdminClubRequestsPage embedded />}
              />
              <Route
                path="applications/new/:requestId"
                element={<AdminClubRequestDetailPage embedded />}
              />
              <Route
                path="applications/reapplications"
                element={<AdminClubReapplicationsPage embedded />}
              />
              <Route
                path="applications/reapplications/:requestId"
                element={<AdminClubReapplicationDetailPage embedded />}
              />

              <Route path="requests" element={<ExecRequestsLayout />}>
                <Route index element={<ExecRequestsIndexRedirect />} />
                <Route
                  path="funding"
                  element={<AdminFundingPlaceholderPage embedded />}
                />
                <Route
                  path="funding/:requestId"
                  element={<AdminClubFundingDetailPage embedded />}
                />
                <Route
                  path="events"
                  element={<AdminEventsPage embedded />}
                />
                <Route
                  path="events/:requestId"
                  element={<AdminClubEventDetailPage embedded />}
                />
                <Route
                  path="promo-lunch"
                  element={<AdminPromoLunchPage embedded />}
                />
                <Route
                  path="promo-lunch/:requestId"
                  element={<AdminPromoLunchDetailPage embedded />}
                />
                <Route
                  path="announcements"
                  element={<AdminAnnouncementsPage embedded />}
                />
                <Route
                  path="announcements/:clubId"
                  element={<AdminClubAnnouncementsDetailPage embedded />}
                />
                <Route
                  path="supervisor"
                  element={<AdminSupervisorRequestsPage embedded />}
                />
                <Route
                  path="supervisor/:clubId"
                  element={<AdminClubSupervisorRequestsDetailPage embedded />}
                />
              </Route>

              <Route
                path="school-day"
                element={<AdminSchoolDayPage embedded />}
              />

              <Route path="archived" element={<ExecArchivedLayout />}>
                <Route index element={<ExecArchivedIndexRedirect />} />
                <Route
                  path="clubs"
                  element={<AdminArchivedClubsPage embedded />}
                />
                <Route
                  path="announcements"
                  element={<AdminArchivedAnnouncementsPage embedded />}
                />
              </Route>

              {/* Legacy redirects — preserve old bookmarks */}
              <Route
                path="announcements"
                element={
                  <Navigate
                    to="/exec-dashboard/requests/announcements"
                    replace
                  />
                }
              />
              <Route
                path="clubs"
                element={
                  <Navigate to="/exec-dashboard/applications/new" replace />
                }
              />
              <Route
                path="reapplications"
                element={
                  <Navigate
                    to="/exec-dashboard/applications/reapplications"
                    replace
                  />
                }
              />
              <Route
                path="funding"
                element={
                  <Navigate to="/exec-dashboard/requests/funding" replace />
                }
              />
              <Route
                path="supervisor-requests"
                element={
                  <Navigate to="/exec-dashboard/requests/supervisor" replace />
                }
              />
              <Route
                path="pending-clubs"
                element={
                  <Navigate to="/exec-dashboard/requests/supervisor" replace />
                }
              />
              <Route
                path="overdue-supervisor"
                element={
                  <Navigate to="/exec-dashboard/requests/supervisor" replace />
                }
              />
              <Route
                path="archived-clubs"
                element={
                  <Navigate to="/exec-dashboard/archived/clubs" replace />
                }
              />
              <Route
                path="inactive-clubs"
                element={
                  <Navigate to="/exec-dashboard/archived/clubs" replace />
                }
              />
              <Route
                path="active-clubs"
                element={
                  <Navigate to="/exec-dashboard/applications/new" replace />
                }
              />
              <Route
                path="events"
                element={
                  <Navigate to="/exec-dashboard/requests/events" replace />
                }
              />
            </Route>

            <Route
              path="register-club"
              element={<Navigate to="/clubs/apply" replace />}
            />
            <Route
              path="my-clubs"
              element={<Navigate to="/clubs/my-clubs" replace />}
            />
            <Route
              path="admin/club-requests"
              element={
                <Navigate to="/exec-dashboard/applications/new" replace />
              }
            />
            <Route
              path="admin/announcements"
              element={
                <Navigate
                  to="/exec-dashboard/requests/announcements"
                  replace
                />
              }
            />

            <Route path="home" element={<Navigate to="/" replace />} />
            <Route path="*" element={<NotFoundPage />} />
          </Route>
          </Routes>
          </AuthRedirectProvider>
          <Analytics />
        </BrowserRouter>
      </AuthProvider>
    </AppProviders>
  );
}
