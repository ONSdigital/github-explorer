$(document).ready(function() {
  $("#data.teams").DataTable({
    stateSave: true,

    // See https://datatables.net/reference/option/dom
    "dom": "frtp"
  });

  $("#data.members").DataTable({

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
    "dom": "frtp"
  });

  $("#data.collaborators").DataTable({

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
    "dom": "frtp"
  });

  $("#data.repositories").DataTable({

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
    "dom": "frtp"
  });

  $("#data.two-factor").DataTable({
    stateSave: true,
    "dom": "frtp"
  });
});
