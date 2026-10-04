import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import { supabase } from "../lib/supabase";
import * as authService from "../services/auth";
import {
  getCurrentProfile,
  getCurrentUserSystemRoles,
} from "../services/profiles";
import { getOwnedClubsForAnnouncements } from "../services/announcements";
import { canCreateAnnouncement } from "../utils/announcementPermissions";
import { isAllowedEmailDomain } from "../utils/domain";
import { getErrorMessage } from "../utils/errors";

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [profile, setProfile] = useState(null);
  const [systemRoles, setSystemRoles] = useState([]);
  const [ownedClubs, setOwnedClubs] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [accessDenied, setAccessDenied] = useState(false);
  const [authError, setAuthError] = useState("");
  const authGenerationRef = useRef(0);

  const clearSessionState = useCallback(() => {
    setUser(null);
    setProfile(null);
    setSystemRoles([]);
    setOwnedClubs([]);
  }, []);

  const refreshProfile = useCallback(async (userId) => {
    const id = userId ?? user?.id;
    if (!id) {
      setProfile(null);
      return null;
    }

    const nextProfile = await getCurrentProfile(id);
    setProfile(nextProfile);
    return nextProfile;
  }, [user?.id]);

  const refreshRoles = useCallback(async (userId) => {
    const id = userId ?? user?.id;
    if (!id) {
      setSystemRoles([]);
      return [];
    }

    const nextRoles = await getCurrentUserSystemRoles(id);
    setSystemRoles(nextRoles);
    return nextRoles;
  }, [user?.id]);

  const refreshOwnedClubs = useCallback(async (userId) => {
    const id = userId ?? user?.id;
    if (!id) {
      setOwnedClubs([]);
      return [];
    }

    const nextClubs = await getOwnedClubsForAnnouncements(id);
    setOwnedClubs(nextClubs);
    return nextClubs;
  }, [user?.id]);

  const processUser = useCallback(
    async (currentUser) => {
      const generation = ++authGenerationRef.current;
      const isCurrent = () => authGenerationRef.current === generation;

      if (!currentUser) {
        clearSessionState();
        setAccessDenied(false);
        setAuthError("");
        setIsLoading(false);
        return;
      }

      if (!isAllowedEmailDomain(currentUser.email)) {
        clearSessionState();
        setAccessDenied(true);
        setAuthError(
          "Only @pdsb.net Google accounts may access this application.",
        );
        setIsLoading(false);
        if (isCurrent()) await authService.signOut();
        return;
      }

      setAccessDenied(false);
      setAuthError("");
      setUser(currentUser);

      let nextError = "";

      try {
        const nextProfile = await getCurrentProfile(currentUser.id);
        if (!isCurrent()) return;
        setProfile(nextProfile);
      } catch (profileError) {
        if (!isCurrent()) return;
        setProfile(null);
        nextError = getErrorMessage(
          profileError,
          "Could not load your profile.",
        );
      }

      try {
        const nextRoles = await getCurrentUserSystemRoles(currentUser.id);
        if (!isCurrent()) return;
        setSystemRoles(nextRoles);
      } catch (rolesError) {
        if (!isCurrent()) return;
        setSystemRoles([]);
        const rolesMessage = getErrorMessage(
          rolesError,
          "Could not load your system roles.",
        );
        if (rolesMessage && rolesMessage !== nextError) {
          nextError = nextError ? `${nextError} ${rolesMessage}` : rolesMessage;
        }
      }

      try {
        const nextClubs = await getOwnedClubsForAnnouncements(currentUser.id);
        if (!isCurrent()) return;
        setOwnedClubs(nextClubs);
      } catch (clubsError) {
        if (!isCurrent()) return;
        setOwnedClubs([]);
        console.error(clubsError);
      }

      if (nextError) {
        setAuthError(nextError);
      }

      if (isCurrent()) setIsLoading(false);
    },
    [clearSessionState],
  );

  useEffect(() => {
    let active = true;

    async function initialize() {
      setIsLoading(true);

      try {
        const currentUser = await authService.getCurrentUser();
        if (!active) return;
        await processUser(currentUser);
      } catch (error) {
        if (!active) return;
        setAuthError(getErrorMessage(error, "Authentication failed."));
        clearSessionState();
        setIsLoading(false);
      }
    }

    initialize();

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      window.setTimeout(() => {
        if (active) {
          processUser(session?.user ?? null);
        }
      }, 0);
    });

    return () => {
      active = false;
      subscription.unsubscribe();
    };
  }, [clearSessionState, processUser]);

  const signInWithGoogle = useCallback(async (idToken) => {
    setAuthError("");
    setAccessDenied(false);
    await authService.signInWithGoogle(idToken);
  }, []);

  const signOut = useCallback(async () => {
    authGenerationRef.current += 1;
    setAuthError("");
    setAccessDenied(false);
    await authService.signOut();
    clearSessionState();
  }, [clearSessionState]);

  const roleCodes = useMemo(
    () => systemRoles.map((role) => role.code),
    [systemRoles],
  );

  const isSacAdmin = roleCodes.includes("SITE_ADMIN");
  const isFacultyAdvisor = false;
  const isSacExec = false;
  const isAdmin = isSacAdmin;
  const canAccessExecDashboard = isSacAdmin;
  const canMutateReviews = isSacAdmin;
  const canMutateSchoolDay = isSacAdmin;
  const canCreateAnnouncements = canCreateAnnouncement({
    isSacAdmin,
    isFacultyAdvisor,
    ownedClubs,
  });

  const value = useMemo(
    () => ({
      user,
      profile,
      systemRoles,
      ownedClubs,
      isAuthenticated: Boolean(user),
      isLoading,
      isSacAdmin,
      isFacultyAdvisor,
      isSacExec,
      isAdmin,
      canAccessExecDashboard,
      canMutateReviews,
      canMutateSchoolDay,
      canCreateAnnouncements,
      accessDenied,
      authError,
      signInWithGoogle,
      signOut,
      refreshProfile,
      refreshRoles,
      refreshOwnedClubs,
      setAuthError,
    }),
    [
      user,
      profile,
      systemRoles,
      ownedClubs,
      isLoading,
      isSacAdmin,
      isFacultyAdvisor,
      isSacExec,
      isAdmin,
      canAccessExecDashboard,
      canMutateReviews,
      canMutateSchoolDay,
      canCreateAnnouncements,
      accessDenied,
      authError,
      signInWithGoogle,
      signOut,
      refreshProfile,
      refreshRoles,
      refreshOwnedClubs,
    ],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

// eslint-disable-next-line react-refresh/only-export-components -- context hook intentionally shares this provider module
export function useAuth() {
  const context = useContext(AuthContext);

  if (!context) {
    throw new Error("useAuth must be used within an AuthProvider.");
  }

  return context;
}
