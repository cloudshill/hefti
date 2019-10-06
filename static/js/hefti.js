'use strict';

$(document).ready(function() {

  $("#add").on("click", function() {
    $(".list-group").append(`
        <li class="list-group-item">
          <div class="idholder">
            <div class="row">
              <div class="input-group mb-3">
                <div class="col-10">
                  <input id="title" type="text" class="form-control"></input>
                </div>
                <div class="col">
                  <input id="spend_time" type="number" class="form-control" value="0"></input>
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
                  <input id="date" type="text" class="form-control" value="` + new Date().toJSON().slice(0,10) + `"></input>
                </div>
              </div>
            </div>
          </div>
        </li>`);
    $("input,select").off("change");
    $("input,select").change(addOrUpdate);
  });

  $("input,select").change(addOrUpdate);
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

function add(object) {
  var entry = {
    title: object.find("#title").val(),
    logdate: object.find("#date").val(),
    entry_type: object.find("#type").val(),
    spend_time: parseFloat(object.find("#spend_time").val())
  };
  $.ajax({url: "/entry/" + id, type: "POST", data: JSON.stringify(entry)});
}

function update(id) {
  var par = $(".idholder#" + id);
  var entry = {
    title: par.find("#title").val(),
    logdate: par.find("#date").val(),
    entry_type: par.find("#type").val(),
    spend_time: parseFloat(par.find("#spend_time").val())
  };
  $.ajax({url: "/entry/" + id, type: "PUT", data: JSON.stringify(entry)});
}

function remove(id) {
  $.ajax({url: "/entry/" + id, type: "DELETE"});
}
