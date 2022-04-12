$(document).ready(function() {
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
