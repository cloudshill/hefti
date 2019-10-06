'use strict';

$(document).ready(function() {

  console.log($("#add"));

  $("#add").on("click", function() {
    $(".list-group").append(`
        <li class="list-group-item">
          <div id="{{id}}">
            <div class="row">
              <div class="input-group mb-3">
                <div class="col-10">
                  <input id="title" type="text" class="form-control"></input>
                </div>
                <div class="col">
                  <input id="duration" type="number" class="form-control"></input>
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
                  <input id="date" type="text" class="form-control"></input>
                </div>
              </div>
            </div>
          </div>
        </li>`);
  });

});
