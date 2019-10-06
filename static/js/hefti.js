'use strict';

$(document).ready(function() {

  $("#add").on("click", function() {
    $(".list-group").append(`
        <li class="list-group-item">
          <div class="idholder">
            <div class="row">
              <div class="input-group mb-3">
                <div class="col-9">
                  <input id="title" type="text" class="form-control"></input>
                </div>
                <div class="col-2">
                  <input id="spend_time" type="number" class="form-control" value="0"></input>
                </div>
                <div class="col-1">
                  <button class="btn btn-danger" id="remove">-</button>
                </div>
              </div>
            </div>
            <div class="row">
              <div class="input-group mb-3">
                <div class="col-3">
                  <div class="form-group">
                    <select id="type" type="text" class="form-control">
                      <option>Betriebliche Tätigkeit</option>
                      <option>Schulung</option>
                      <option>Berufschule</option>
                    </select>
                  </div>
                </div>
                <div class="col-7"></div>
                <div class="col-2">
                  <input id="datepicker" type="text" class="form-control" value="` + new Date().toJSON().slice(0,10) + `"></input>
                </div>
              </div>
            </div>
          </div>
        </li>`);
    $("input,select").off("change");
    $("input,select").change(addOrUpdate);
    $("remove").off("click");
    $("remove").click(remove);
    $("#datepicker").datetimepicker({format: 'YYYY-MM-DD'}).on("dp.change", addOrUpdate);
  });

  $("input,select").change(addOrUpdate);
  $("#remove").click(remove);

  $(".datepicker").datetimepicker({format: 'YYYY-MM-DD'}).on("dp.change", addOrUpdate);
});


function addOrUpdate() {
  var obj = $(this).parents(".idholder");
  var entry = {
    title: obj.find("#title").val(),
    logdate: obj.find("#date").val(),
    entry_type: obj.find("#type").val(),
    spend_time: parseFloat(obj.find("#spend_time").val())
  };
  if (obj.attr("id") === undefined) {
    $.ajax({url: "/entry", type: "POST", data: JSON.stringify(entry), success: function(data){obj.attr("id", data)}});
  } else {
    $.ajax({url: "/entry/" + obj.attr("id"), type: "PUT", data: JSON.stringify(entry)});
  }
}

function remove() {
  var obj = $(this).parents(".idholder");
  if (obj.attr("id") !== undefined) {
    $.ajax({url: "/entry/" + obj.attr("id"), type: "DELETE"});
  }
  obj.parent(".list-group-item").remove();
}
