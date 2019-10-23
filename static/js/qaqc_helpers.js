
//for subsetting time series by desired window
function getdisplaydata(start, end, dat){
  stdt = Date.parse(start) //convert from YYYY-MM-DD to unix
  endt = Date.parse(end)
  pltdat = $(dat).filter(function(i, n){
    return Date.parse(n.DateTime_UTC) > stdt && Date.parse(n.DateTime_UTC) < endt
  })
  return $.makeArray(pltdat)
}

//compare variable
$(function(){
  $("#backgraphlist2").change(function () {

    if($(this).val() == 'None'){

      // remove previous graph and secondary axis
      d3.selectAll('.backgraph').select("path").remove()
      d3.selectAll('[id*=rightaxis]').attr("visibility", "hidden");
    } else {

      //plot polygon for secondary variable
      var backfill = this.value;
      for (var i = 0; i < variables.length; ++i) {
        BackGraph(backfill, variables[i], data, type='polygon');
      }
    }

  });
})

//panback
$(function(){
  $("#panback").click(function(){

    // if the start date is not the last date in the list (i.e. the oldest)
    if(plotstart != plotdates.slice(-1)[0]){
      plotend = plotstart;
      plotstart = plotdates[plotdates.indexOf(plotstart) + 1];
      // if(datna != null){
      //   data = getdisplaydata(plotstart,plotend,alldatna);
      // }else{
      data = getdisplaydata(plotstart, plotend, alldata);
      // }
      async_replot(data=data)
    }
  });
})

//panforward
$(function(){
  $("#panforward").click(function(){

    // if the end date is not the first date in the list
    if(plotend != plotdates[0]){
      plotstart = plotend;
      plotend = plotdates[plotdates.indexOf(plotend)-1];
      // if(datna != null){
      //   data = getdisplaydata(plotstart,plotend,alldatna);
      // }else{
      data = getdisplaydata(plotstart,plotend,alldata);
      // }
      async_replot(data=data)
    }
  });
})

//jumptodate
$(function(){
  $('#jumptodate').change(function(){
    daterange_val = this.value
    daterange_vals = daterange_val.split(' ')
    plotstart = daterange_vals[0]
    plotend = daterange_vals[1]
    data = getdisplaydata(plotstart, plotend, alldata);
    async_replot(data=data)
  })
})

function alertbox(alrt, msg){
  return '<div class="alert alert-dismissible alert-' + alrt + '">\
    <button class="close" data-dismiss="alert" aria-label="close">&times;</button>\
    ' + msg + '</div>'
}

// add flags for all highlighted points when yellow popup button is clicked
$('body').ready(function(){
  $('body').on("click", "#addflag2", function(){
    add_flag(red_points_only=false);
  });
});

// add flags for red highlighted points when red popup button is clicked
$('body').ready(function(){
  $('body').on("click", "#addflag_outl", function(){
    add_flag(red_points_only=true);
  });
});

// remove flags when green popup button is clicked
$('body').ready(function(){
  $('body').on("click", "#rmflag", function(){
    rm_flag();
  });
});

// highlight/unhighlight across all variables when "apply vertically..." is toggled
$('body').ready(function(){
  $('body').on("input", "#fillbrush", selection_manager);
});

function selection_manager() {

  var brsh = d3.brushSelection(d3.select("#" + selectedBrush).node())

  if (typeof $('#fillbrush')[0] != 'undefined') {

    var b_strt = x.invert(brsh[0]);
    var b_end = x.invert(brsh[1]);

    if( $('#fillbrush')[0].checked ){
      brushdown = true;
      d3.selectAll(".dot, .maybe_outl, .highlighted").classed("selected",
        function(d) { return b_strt <= d.date && d.date <= b_end; });

    } else {

      brushdown = false;
      d3.selectAll(".selected").classed("selected", false);
      d3.select("." + selectedBrush)
        .selectAll(".dot, .maybe_outl, .highlighted")
        .classed("selected", function(d) {
          return b_strt <= d.date && d.date <= b_end;
        });
    }
  }

  return false
}

function rm_flag() {

  if(undefined != selectedBrush){ // only do this if there is a brush selected

    s = d3.brushSelection(d3.select("#"+selectedBrush).node())
    dat = {}
    dat['site'] = $('select[name=site]').val();
    dat['startDate'] = x.invert(s[0]);
    dat['endDate'] = x.invert(s[1]);

    if(brushdown){
      dat['var'] = variables;
      b = d3.selectAll("svg").selectAll(".selected");
    } else {
      dat['var'] = [selectedBrush];
      b = d3.select("." + selectedBrush).selectAll(".selected");
    }

    b.classed('highlighted', function(d) {
      is_brushed = dat['startDate'] <= d.date && d.date <= dat['endDate'];
      return ! is_brushed;
    });

    b.classed('flagdot', function(d) {
      is_brushed = dat['startDate'] <= d.date && d.date <= dat['endDate'];
      return ! is_brushed;
    });

    brushdown = false;
    rmflag_ajax();

    return false;

  } else {

    $("#alerts_floating").append(alertbox('warning', 'No points selected.'));
  }
}

function add_flag(red_points_only) {

  if(undefined != selectedBrush){ // only do this if there is a brush selected

    if( $('#qaqc select').val() == null ){
      $("#alerts_floating").append(alertbox('danger','Please select a flag label.'));
      return false
    }

    s = d3.brushSelection(d3.select("#" + selectedBrush).node())
    dat = {}
    dat['site'] = $('select[name=site]').val();
    dat['startDate'] = x.invert(s[0]);
    dat['endDate'] = x.invert(s[1]);

    if(brushdown){
      dat['var'] = variables;
      b = d3.selectAll("svg").selectAll(".dot");
      if(red_points_only){
        b = b.filter('.maybe_outl');
      }
    } else {
      dat['var'] = [selectedBrush];
      b = d3.select("." + selectedBrush).selectAll(".selected");
      if(red_points_only){
        b = b.filter('.maybe_outl');
      }
    }

    b.classed('highlighted', function(d) {
      is_brushed = dat['startDate'] <= d.date && d.date <= dat['endDate'];
      return is_brushed;
    });

    brushdown = false;
    dat['comment'] = $("input[name=fcomment2]").val();
    dat['flagid'] = $("select[name=flagID2]").val();

    if(red_points_only){
      so = d3.selectAll(".highlighted").filter('.maybe_outl').data();
      counter = 0; //prepare for flag_ajax_serial recursion
      dat['startDate'] = so[counter].DateTime_UTC; //focus on first red point
      dat['endDate'] = so[counter].DateTime_UTC;
    }

    if (dat.flagid != null){

      if(red_points_only){
        flag_ajax_serial(counter, so);
      } else {
        flag_ajax_batch();
      }
      return false;

    } else {
      $("#alerts_floating").append(alertbox('warning','Please select a flag label.'));
    }

  } else {
    $("#alerts_floating").append(alertbox('warning','No points selected.'));
  }
}

//flag all selected points, the fast way
function flag_ajax_batch(){
  $.ajax({
    type: 'POST',
    url:'/_addflag',
    data: JSON.stringify(dat),
    contentType: 'application/json;charset=UTF-8',
    success: function(){
      $('.popupbox').remove();
      console.log("success");
    },
    error: function(error){
      $('.popupbox').remove();
      console.log(error);
    }
  });
}

//flag only selected points that are red. waits for callbacks
function flag_ajax_serial(counter, selection){
  $.ajax({
    type: 'POST',
    url:'/_addflag',
    data: JSON.stringify(dat),
    contentType: 'application/json;charset=UTF-8',
    success: function(){
      if (counter < so.length - 1){
        counter++;
        dat['startDate'] = so[counter].DateTime_UTC; //focus on next red point
        dat['endDate'] = so[counter].DateTime_UTC;
        flag_ajax_serial(counter, so);
      } else {
        $('.popupbox').remove();
      }
    },
    error: function(error){
      $('.popupbox').remove();
      console.log(error);
    }
  });
}

//remove all flags from selected points
function rmflag_ajax(){
  $.ajax({
    type: 'POST',
    url:'/_rmflag',
    data: JSON.stringify(dat),
    contentType: 'application/json;charset=UTF-8',
    success: function(){
      $('.popupbox').remove();
      console.log("success");
    },
    error: function(error){
      $('.popupbox').remove();
      console.log(error);
    }
  });
}
