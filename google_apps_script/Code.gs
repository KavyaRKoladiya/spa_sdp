/**
 * Google Apps Script Web App for Study Planner App
 * 
 * How it works:
 * 1. Linked to the Google Sheet that collects Google Form quiz responses.
 * 2. When the Flutter app queries this Web App with ?action=getScore&email=student@example.com,
 *    it searches the sheet for the student's submission and returns the score in JSON format.
 * 3. Does NOT require any private keys or service accounts inside the Flutter app.
 */

function doGet(e) {
  try {
    // If accessed with no query params (e.g. in browser), return health check
    if (!e || !e.parameter || !e.parameter.email) {
      return createJsonResponse({
        status: "success",
        message: "Study Planner Quiz Sync API is running.",
        usage: "Send a GET request with ?action=getScore&email=<student_email>&quizId=<optional_id>"
      });
    }

    var targetEmail = e.parameter.email.trim().toLowerCase();
    var sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
    var data = sheet.getDataRange().getValues();

    if (data.length <= 1) {
      return createJsonResponse({
        status: "success",
        found: false,
        message: "No quiz responses have been submitted to this sheet yet."
      });
    }

    // Inspect headers (row 0)
    var headers = data[0];
    var emailColIndex = -1;
    var scoreColIndex = -1;
    var timestampColIndex = -1;

    for (var i = 0; i < headers.length; i++) {
      var header = headers[i].toString().trim().toLowerCase();
      if (header.indexOf("email") !== -1 || header.indexOf("username") !== -1) {
        emailColIndex = i;
      } else if (header.indexOf("score") !== -1) {
        scoreColIndex = i;
      } else if (header.indexOf("timestamp") !== -1) {
        timestampColIndex = i;
      }
    }

    // Fallbacks if standard Google Form header names vary:
    // Typically: Col 0 = Timestamp, Col 1 = Email Address, Col 2 = Score
    if (emailColIndex === -1 && headers.length > 1) {
      emailColIndex = 1; // Default Google Forms email column
    }
    if (scoreColIndex === -1 && headers.length > 2) {
      scoreColIndex = 2; // Default Google Forms quiz score column
    }
    if (timestampColIndex === -1) {
      timestampColIndex = 0;
    }

    // Search from bottom up to find the latest submission by this student
    var latestSubmission = null;
    for (var r = data.length - 1; r >= 1; r--) {
      var row = data[r];
      var rowEmail = (row[emailColIndex] || "").toString().trim().toLowerCase();

      if (rowEmail === targetEmail) {
        latestSubmission = {
          timestamp: row[timestampColIndex],
          rawScore: row[scoreColIndex]
        };
        break;
      }
    }

    if (!latestSubmission) {
      return createJsonResponse({
        status: "success",
        found: false,
        email: targetEmail,
        message: "No submission found for " + targetEmail + ". Please submit the quiz first."
      });
    }

    // Parse score (Google Forms formats scores as "8 / 10" or "80 / 100" or raw numbers)
    var parsed = parseScore(latestSubmission.rawScore);

    return createJsonResponse({
      status: "success",
      found: true,
      email: targetEmail,
      score: parsed.score,
      totalMarks: parsed.totalMarks,
      percentage: parsed.percentage,
      submittedAt: latestSubmission.timestamp
    });

  } catch (err) {
    return createJsonResponse({
      status: "error",
      message: err.toString()
    });
  }
}

/**
 * Parses raw score from Google Forms response column (e.g. "8 / 10" or 8)
 */
function parseScore(rawScore) {
  var score = 0;
  var totalMarks = 10;

  if (typeof rawScore === "number") {
    score = rawScore;
  } else if (typeof rawScore === "string") {
    var parts = rawScore.split("/");
    if (parts.length === 2) {
      score = parseFloat(parts[0].trim()) || 0;
      totalMarks = parseFloat(parts[1].trim()) || 10;
    } else {
      score = parseFloat(rawScore.trim()) || 0;
    }
  }

  var percentage = totalMarks > 0 ? (score / totalMarks) * 100 : 0;
  return {
    score: score,
    totalMarks: totalMarks,
    percentage: Math.round(percentage * 100) / 100
  };
}

/**
 * Creates a JSON response with proper ContentType
 */
function createJsonResponse(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
