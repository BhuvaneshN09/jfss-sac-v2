/**
 * Official JFSS club list sync for Google Sheets.
 *
 * Setup:
 * 1. Extensions → Apps Script, paste this file, save.
 * 2. Project Settings → Script properties:
 *      CLUB_SHEET_URL = https://www.johnfrasersac.com/api/club-sheet
 *      CLUB_SHEET_KEY = (same value as Vercel CLUB_SHEET_SYNC_KEY)
 * 3. Run installClubSheetTrigger() once and approve permissions.
 * 4. Optional: run syncOfficialClubs() immediately to fill the sheet.
 */

var SHEET_NAME = "Official Clubs";
var HEADER_ROW = 3;

var HEADERS = [
  "Club name",
  "New or old",
  "Description",
  "Club leader(s)",
  "Teacher supervisor(s)",
  "Meeting dates",
  "Club location",
  "Contact information",
  "Member application",
  "Exec application",
  "School year",
  "Last updated",
  "Club ID",
];

function syncOfficialClubs() {
  var props = PropertiesService.getScriptProperties();
  var url = String(props.getProperty("CLUB_SHEET_URL") || "").trim();
  var key = String(props.getProperty("CLUB_SHEET_KEY") || "").trim();

  if (!url || !key) {
    throw new Error(
      "Set CLUB_SHEET_URL and CLUB_SHEET_KEY in Project Settings → Script properties.",
    );
  }

  var response = UrlFetchApp.fetch(url, {
    method: "get",
    muteHttpExceptions: true,
    followRedirects: true,
    headers: {
      "X-Club-Sheet-Key": key,
    },
  });

  var status = response.getResponseCode();
  var body = response.getContentText();
  if (status !== 200) {
    throw new Error("Club sheet sync failed (" + status + "): " + body);
  }

  var payload = JSON.parse(body);
  var clubs = payload.clubs || [];
  var generatedAt = payload.generatedAt || new Date().toISOString();
  var sheet = getOrCreateSheet_();

  sheet.clear();
  sheet.getRange(1, 1).setValue("SAC Approved Supercouncil Clubs List");
  sheet
    .getRange(2, 1)
    .setValue(
      "Auto-updated from johnfrasersac.com · Last synced " +
        formatTimestamp_(generatedAt) +
        " · " +
        clubs.length +
        " clubs",
    );

  sheet.getRange(HEADER_ROW, 1, 1, HEADERS.length).setValues([HEADERS]);
  sheet.getRange(HEADER_ROW, 1, 1, HEADERS.length).setFontWeight("bold");

  if (clubs.length > 0) {
    var rows = clubs.map(function (club) {
      return [
        club.club_name || "",
        club.club_type || "",
        club.description || "",
        club.club_leaders || "",
        club.teacher_supervisors || "",
        club.meeting_dates || "",
        club.club_location || "",
        club.contact_information || "",
        club.member_application_url || "",
        club.exec_application_url || "",
        club.school_year || "",
        formatTimestamp_(club.updated_at),
        club.club_id || "",
      ];
    });
    sheet
      .getRange(HEADER_ROW + 1, 1, rows.length, HEADERS.length)
      .setValues(rows);
  }

  sheet.setFrozenRows(HEADER_ROW);
  sheet.autoResizeColumns(1, HEADERS.length);
  if (sheet.getMaxColumns() >= 13) {
    sheet.hideColumns(13);
  }
}

function installClubSheetTrigger() {
  var triggers = ScriptApp.getProjectTriggers();
  for (var i = 0; i < triggers.length; i++) {
    if (triggers[i].getHandlerFunction() === "syncOfficialClubs") {
      ScriptApp.deleteTrigger(triggers[i]);
    }
  }

  ScriptApp.newTrigger("syncOfficialClubs").timeBased().everyMinutes(5).create();
  syncOfficialClubs();
}

function getOrCreateSheet_() {
  var spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = spreadsheet.getSheetByName(SHEET_NAME);
  if (!sheet) {
    sheet = spreadsheet.insertSheet(SHEET_NAME);
  }
  return sheet;
}

function formatTimestamp_(value) {
  if (!value) return "";
  var date = new Date(value);
  if (isNaN(date.getTime())) return String(value);
  return Utilities.formatDate(
    date,
    "America/Toronto",
    "yyyy-MM-dd h:mm a",
  );
}
