$(function() {
  $("#filter").on("keyup", function(event) {
    var filter, tr, td, i, cellText;
    filter = $("#filter").val().toUpperCase();
    tr = $("#data").find("tr");

    // Loop through all table rows, and hide those who don't match the search query
    for (i = 0; i < tr.length; i++) {
      td = tr[i].getElementsByTagName("td")[0];
      if (td) {
        cellText = td.textContent || td.innerText;
        if (cellText.toUpperCase().indexOf(filter) > -1) {
          tr[i].style.display = "";
        } else {
          tr[i].style.display = "none";
        }
      } 
    }
  });
});
