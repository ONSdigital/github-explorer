$(document).ready(function() {
  displayDatesInLocalTime();

  function displayDatesInLocalTime() {
    const dateElements = document.querySelectorAll('.date');
  
    dateElements.forEach(element => {
      const utcDateStr = element.textContent.trim();
      const localDateStr = parseAndConvertToLocalTime(utcDateStr + ':00');
  
      element.textContent = localDateStr;
    });
  }

  function parseAndConvertToLocalTime(utcDateString) {
    if (utcDateString === "-") {
      return "-";
    }
  
    const [day, month, year, time] = utcDateString.split(' ');
  
    const months = {
        Jan: '01', Feb: '02', Mar: '03', Apr: '04', May: '05', Jun: '06',
        Jul: '07', Aug: '08', Sep: '09', Oct: '10', Nov: '11', Dec: '12'
    };
  
    const formattedUTCDate = `${year}-${months[month]}-${day}T${time}Z`;
    const dateObj = new Date(formattedUTCDate);
    const datePart = dateObj.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
    const timePart = dateObj.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit', hour12: false });

    return `${datePart} ${timePart}`;
  }

  $("#selected-organisation").change(function() {
    Cookies.set('github-explorer-organisation', $(this).val());
    window.location.reload();
  });

  $("#data.teams").DataTable({
    buttons: [
      "csv", "excel", "pdf"
    ],
    stateSave: true,

    // See https://datatables.net/reference/option/dom
    "dom": "fBrtp"
  });

  $("#data.teamless").DataTable({
    buttons: [
      "csv", "excel", "pdf"
    ],

    // Prevent sorting the Two Factor Security column.
    columns: [
      null,
      null,
      null,
      { orderable: false },
      null,
      null
    ],
    stateSave: true,
    "dom": "fBrtp"
  });

  $("#data.members").DataTable({
    buttons: [
      "csv", "excel", "pdf"
    ],

    // Prevent sorting the Two Factor Security column.
    columns: [
      null,
      null,
      null,
      { orderable: false },
      null,
      null
    ],
    stateSave: true,
    "dom": "fBrtp"
  });

  $("#data.collaborators").DataTable({
    buttons: [
      "csv", "excel", "pdf"
    ],

    // Prevent sorting the Two Factor Security column.
    columns: [
      null,
      null,
      null,
      { orderable: false },
      null,
      null,
      null
    ],
    stateSave: true,
    "dom": "fBrtp"
  });

  $("#data.contributions").DataTable({
    buttons: [
      "csv", "excel", "pdf"
    ],
    stateSave: true,
    "dom": "fBrtp"
  });

  $("#data.inactive").DataTable({
    buttons: [
      "csv", "excel", "pdf"
    ],

    // Prevent sorting the Two Factor Security column.
    columns: [
      null,
      null,
      null,
      { orderable: false },
      null,
      null,
      null
    ],
    stateSave: true,
    "dom": "fBrtp"
  });

  $("#data.repositories").DataTable({
    buttons: [
      "csv", "excel", "pdf"
    ],

    // Prevent sorting the Branch Protection Rules column.
    columns: [
      null,
      null,
      null,
      { orderable: false },
      null,
      null,
      null,
      null
    ],
    stateSave: true,
    "dom": "fBrtp"
  });

  $("#data.two-factor").DataTable({
    buttons: [
      "csv", "excel", "pdf"
    ],
    stateSave: true,
    "dom": "fBrtp"
  });
});
