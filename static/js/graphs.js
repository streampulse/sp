var margin = {top: 40, right: 60, bottom: 40, left: 40},
    width = $("#graphs").width() - margin.left - margin.right,
    height = 250 - margin.top - margin.bottom;
var parseDate = d3.utcParse("%Y-%m-%dT%H:%M:%S.%LZ");
var x = d3.scaleUtc().range([0, width]),
    y = d3.scaleLinear().range([height, 0]),
    xAxis = d3.axisBottom().scale(x).ticks(6).tickFormat(function(date, i){
      //conditional date formatting on tickmarks
      return (i == 0 ? d3.utcFormat("%b %e, %Y") : d3.utcFormat("%b %e"))(date);
    });
var brush = d3.brushX()
  // .extent([0, 0], [width, height])
  .on("start", brushstart)
  .on("brush", brushmove)
  .on("end", brushend);
var selectedBrush;
var data;
var variables;
var sundat;
var flags;
var datna;
var zoom_in;
var brushdown = false; //variable for if brushing all panels
var dott_undef //for disabling popup options if no points selected
// var flagdict = {}
var div = d3.select("body").append("div")
    .attr("class", "tooltip")
    .style("opacity", 0);

function Plots(variables, data, flags, outliers, page){

  data.forEach(function(d){ d.date = parseDate(d['DateTime_UTC']) });
  flags.forEach(function(d){ d.date = parseDate(d['DateTime_UTC']) });

  //set x domain to extent of dates
  x.domain(d3.extent(data, function(d) { return d.date; }));

  for (var i = 0; i < variables.length; ++i) {
    vvv = variables[i];

    //set y domain to extent of data
    if(datna != null){ // check if NA, need to rescale Y axis
      y.domain(d3.extent(datna, function(d) { return d[vvv]; }));
    }else{
      y.domain(d3.extent(data, function(d) { return d[vvv]; }));
    }

    //create line accessor and handler for ignoring undefined values
    var line = d3.line()
      .defined(function(d){return d[vvv];})
      .x(function(d) { return x(d.date); })
      .y(function(d) { return y(d[vvv]); });

    var svg = d3.select("#graphs").append("svg")
      .datum(data) //initialize and position
        .attr("class",vvv)
        .attr("width", width + margin.left + margin.right)
        .attr("height", height + margin.top + margin.bottom)
      .append("g")
        .attr("transform", "translate(" + margin.left + "," + margin.top + ")");
    svg.append("g") //x axis and x label
        .attr("class", "axis axis--x")
        .attr("transform", "translate(0," + height + ")")
        .call(xAxis)
        .append("text") //label here
          .attr("fill", "#000")
          .attr("dy", "3em")
          .attr("dx", width)
          .style("text-anchor", "end")
          .text("DateTime (UTC)");
    svg.append("g")
        .attr("class", "axis axis--y")
        .call(d3.axisLeft().scale(y).ticks(3))
        // .selectAll('.line')
        //   .attr('stroke', 'red')
      .append("text")
        .attr("fill", "#000")
        .attr("dy", "-0.71em")
        .attr("dx", "0.71em")
        .attr('class', vvv + '_txt')
        .style("text-anchor", "start")
        .text(vvv);

    svg.append("g") //secondary axis for overlays (technically underlays)
        .attr('id', vvv + 'rightaxis')
        .attr("class", "axis axis--y")
        .attr("transform", "translate(" + width + ", 0)");

    svg.append("g")
        .attr("class", "backgraph");
    svg.append("g")
        .attr("class", "sunriseset");
    // flagobj = {}
    // data.forEach(function(e){
    //   flagobj[e.DateTime_UTC] = [e.varia
    dff = {} // flagged values
     // flagarray.push({vvv: []})
    // flagdict[vvv] = []
    flags.forEach(function(e){
      if(e.variable == vvv){ // only if this is the right variable
        dff[e.DateTime_UTC] = e.variable
        // flagdict[vvv].push(e.flag)
      }
    });
    // code for qaqc page
    if(page=="qaqc"){
      svg.on('dblclick',function(){ redrawPoints(zoom_in=true, sbrush=selectedBrush, reset=true) });
      svg.append("g").attr("class","brush")
        .attr("id", vvv)
        .call(brush);
      svg.selectAll(".dot")
          .data(data.filter(function(d) { return d[vvv]; }))
        .enter().append("circle")
          .attr("class", "dot")
          .attr("cx", line.x())
          .attr("cy", line.y())
        .classed("maybe_outl", function(d, j){
          return outliers[vvv] && outliers[vvv].includes(j+1) &&
            vvv != dff[d.DateTime_UTC];
        })
        .attr("r", function(d, j){
          if(outliers[vvv] && outliers[vvv].includes(j+1) &&
            vvv != dff[d.DateTime_UTC]) {
            return 3
          } else {
            return 2
          };
        })
        .classed("flagdot", function(d){
          return vvv == dff[d.DateTime_UTC]
        })
        .filter('.flagdot')
        .on("mouseover", function(d, j) {

          //get the name (which for some reason is a class) of the svg under the mouse
          var hovered_point = this.getBoundingClientRect();
          var elems = document.elementsFromPoint(hovered_point.x, hovered_point.y);
          for(var i = 0; i < elems.length; ++i){
            if(elems[i].tagName.toLowerCase() == 'svg'){
              var svgname = elems[i].classList[0];
            }
          }

          var this_point_flaginfo = $.grep(flags, function(v) {
            return v.DateTime_UTC == d.DateTime_UTC && v.variable == svgname;
          })[0];

          div.transition()
            .duration(200)
            .style("opacity", .9);
          div.html('Flag: ' + this_point_flaginfo.flag + '<br>Comment: ' +
            this_point_flaginfo.comment)
            .style("left", (d3.event.pageX) + "px")
            .style("top", (d3.event.pageY - 28) + "px");
          })
          .on("mouseout", function(d) {
            div.transition()
              .duration(500)
              .style("opacity", 0);
          });

      //non-flagged points shouldnt register mouse activity
      svg.selectAll('.dot:not(.flagdot)')
        .attr('pointer-events', 'none');

    }else{ // viz page
      svg.append("path")
          .attr("class", "line")
          .attr("d", line);
      svg.selectAll(".vdot")
          .data(data.filter(function(d) { return d[vvv]; }))
        .enter().append("circle")
          .attr("class", "vdot")
          .attr("cx", line.x())
          .attr("cy", line.y())
          .attr("r", 2)
        .classed("flagdot", function(d){
          return vvv == dff[d.DateTime_UTC]
        });
    }
  }
}

function Sunlight(variables, sundat){
  console.time('sun')
  d3.selectAll(".sunriseset").remove();
  extent = x.domain();
  for (var i = 0; i < variables.length; ++i) {
    vvv = variables[i];
    d3.select("."+vvv).selectAll('.sunriseset')
        .data(sundat)
      .enter().append('rect')
        .attr('class', 'sunriseset')
        .attr('x', function(d) { return x(d.set); })
        .attr('y', 0)
        .attr('width', function(d) { return x(d.rise) - x(d.set); })
        .attr('height', height)
        .attr("transform", "translate(" + margin.left + "," + margin.top + ")")
        .attr("pointer-events", "none")
      .classed("outside", function(d) {
        is_inplot = extent[0] > d.rise || d.set > extent[1];
        return is_inplot;
      });
  }
  console.timeEnd('sun')
}

$(function(){
  $('#shownight').change(function() {
    if($(this).is(":checked")) {
      Sunlight(variables, sundat);
    }else{
      d3.select("#graphs").selectAll(".sunriseset").remove();
    }
  });
})

function BackGraph(vvv, graph, data){

  //make new y axis scale and select graph
  var ynew = d3.scaleLinear().range([height, 0]);
  cur_backgraph = d3.select("." + graph).select(".backgraph")

  // remove previous graph and secondary axis if it exists
  cur_backgraph.select("path").remove()
  d3.select('#' + graph + 'rightaxis').empty();

  if(datna != null){
    ynew.domain(d3.extent(datna, function(d) { return d[vvv]; }));
  }else{
    ynew.domain(d3.extent(data, function(d) {
      return d[vvv]; }));
  }

  var area = d3.area()
      .defined(function(d){
        if(d[vvv]==null || d.date < x.domain()[0] || d.date > x.domain()[1]){
          rrr = false
        }else{
          rrr = true
        }
        return rrr
      });
  area.x(function(d) {
         return x(d.date); });
  area.y0(height).y1(function(d) {
        return ynew(d[vvv]); });

  cur_backgraph.append("path")
    .datum(data)
    .attr("class", "backarea")
    .attr("d", area);

  // refresh right-hand axis
  d3.select("#" + graph + 'rightaxis')
      .call(d3.axisRight().scale(ynew).ticks(3))
      .attr('class', 'backarea backarea_axis');
}

$(function(){
  $("#backgraphlist").change(function () {

    var backfill = this.value;

    //reset the other dropdown
    $('#backgraphlist_grab').val('None'); //why doesn't this set off a feedback loop?

    //if requested backfill var not already loaded, go get it
    if(!variables.includes(backfill)){
      var dat = {}
      dat['site'] = $('select[name=site]').val();
      dat['startDate'] = $("#datepicker").data('daterangepicker').startDate.format('YYYY-MM-DD');
      dat['endDate'] = $("#datepicker").data('daterangepicker').endDate.format('YYYY-MM-DD');
      dat['variables'] = [backfill]

      $.ajax({
        type: 'POST',
        url:'/_getviz',
        data: JSON.stringify(dat),
        contentType: 'application/json;charset=UTF-8',
        success: function(response){
          backfilldata = JSON.parse(response.dat);

          //what is up with this heinous need for date duplication??
          //investigate the Backgraph function first
          backfilldata.forEach(function(d){
            d.date = parseDate(d['DateTime_UTC'])
          });

          for(var i = 0; i < variables.length; ++i) {
            BackGraph(backfill, variables[i], backfilldata);
          }
        },
        error: function(error){
          console.log(error);
        }
      });

    } else {
      for (var i = 0; i < variables.length; ++i) {
        BackGraph(backfill, variables[i], data);
      }
    }

  });
})

// Clear the previously active brush, if any.
function brushstart(){
  $('.popupbox').remove();
  d3.select("."+selectedBrush).select(".brush").call(brush.move, null);
  d3.selectAll(".dot").classed("selected", false); // clear on new start
  // d3.selectAll(".brush").clear();
  // d3.selectAll(".brush").call(brush.move, null);
  selectedBrush = $(this).attr("id")
  // selection_manager();
  brushdown = false;
}

function brushmove(){
  var s = d3.event.selection;
  if (s) {
    ext0 = x.invert(s[0]);
    ext1 = x.invert(s[1]);
    // if(brushdown){ // select all dots (bad feature; removed)
    //   var dott = d3.selectAll(".dot, .maybe_outl, .highlighted")
    // }else{ // select just the dots in plot window = selectedBrush
    var dott = d3.select("." + selectedBrush).selectAll(".dot, .maybe_outl")
    // }
    dott.classed("selected", function(d) {
      is_brushed = ext0 <= d.date && d.date <= ext1;
      return is_brushed;
    });
  }

  //helps make sure the options bubble doesnt show up if there's no data selected
  if (typeof dott == 'undefined') {
    dott_undef = true
  } else {
    dott_undef = false
  }

}

function brushend(){

  $('.popupbox').remove();

  // var popupx = d3.select('.' + selectedBrush)
  //   .select('.brush')
  //   .select('.selection')
  //   .attr('x');

  var popupx = document.querySelector('.' + selectedBrush + '_txt')//based on plot title
    .getBoundingClientRect().right;

  var popupy = document.querySelector('.' + selectedBrush + '_txt')
    .getBoundingClientRect().bottom + window.scrollY;

  //if i run into trouble, reset flags2, flagID2, fcomment2, qaqc2
  //can eventually comment the part in qaqc.html about #addflag

  html_str = '<form id="qaqc">'
    + '<div>'
    + '<select id="flags2" '
    + 'name="flagID2" class="v_align">'
    + '<option value="" disabled selected hidden>Choose a flag label</option>'
    + '<option value="Questionable">Questionable</option>'
    + '<option value="Interesting">Interesting</option>'
    + '<option value="Bad Data">Bad Data</option>'
    + '</select>'
    + '<input type="text" name="fcomment2" class="form-control v_align" '
    + 'style="width: 26em;"'
    + 'placeholder=\'Opt. flag comments (e.g. "Sensor out of water")\'>'
    + '</div><div>'
    + '<div class="v_align" style="width: .5em"></div><p class="v_align" style="font: 10pt sans-serif">Apply flag to <br> all variables:</p> <input type="checkbox" id="fillbrush" value="yes"><div class="v_align" style="width: .5em"></div>'
    + '<button class="btn btn-warning btn-xs v_align" type="button" '
    + 'id="addflag2">Flag all<br />selected points</button>'
    + '<button class="btn btn-danger btn-xs v_align" type="button" '
    + 'id="addflag_outl">Flag selected<br />"outliers" (red points)</button>'
    + '<button class="btn btn-success btn-xs v_align" type="button" '
    + 'id="rmflag">Remove all<br />selected flags</button>'
    + '<div class="v_align" style="width: .5em"></div>'
    + '<button class="btn btn-primary btn-xs v_align" type="button" '
    + 'id="zoomin">Zoom in to<br />selected region</button>'
    + '</div>'
    + '</form>'

  if (!dott_undef) {

    //get height of popup to offset by later
    var height_of_popupbox = d3.select('body')
      .append('div')
      .attr('class', 'popupbox')
      .html(html_str).node().getBoundingClientRect().height

    $('.popupbox').remove();

    //create tooltop
    d3.select('body')
      .append('div')
      .attr('class', 'popupbox')
      .html(html_str)
      // .html('<button class="btn btn-danger btn-xs v_align" type="button" id="addflag_outl">Flag red<br />points</button>')
      // .style("opacity", 0);
      // .transition()
  	  //   .duration(500)
  	  //   .style("opacity", 0)
  	  // .transition()
  	  // .duration(200)
  	  // .style("opacity", .9)
      .style('left', (popupx) + 3 + 'px')
      .style('top', (popupy) - height_of_popupbox + 'px');
      // .style("text-anchor", "start");

  }
}

function redrawPoints(zoom_in, sbrush, reset){
  sbb = d3.select("."+sbrush).select(".brush").node()
  if(!sbb){ // check if there is a brush
    s = null
  }else{ // if it exists, get the extent
    s = d3.brushSelection(sbb)
  }
  if(!s || reset){ // nothing selected or resetting graph, extent goes to maximum
    extent = d3.extent(data, function(d) { return d.date; })//"none"
  }else{ // calculate extent bounds
    ext0 = x.invert(s[0])
    ext1 = x.invert(s[1])
    extent = [ext0,ext1]
  }
  if(zoom_in){ // if zooming, reset the extent
    x.domain(extent);
  }

  // if(reset){ extent = "none" }
  // if(extent=="none"){ // reset view, zoom out
  //   extent = d3.extent(data, function(d) { return d.date; })
  //   x.domain(extent);
  // }else{
  // } // otherwise, just flagging?

  // redraw data
  for (var i = 0; i < variables.length; ++i) {
    vvv = variables[i];
    // if(datna != null){
    // dna = {}
    // data.forEach(function(e){dna[e.DateTime_UTC]=e[vvv]})
    // //   y.domain(d3.extent(datna, function(d) { return d[vvv]; })); // reset Y to get rid of NA values
    // // }else{
    // // }
    // y.domain(d3.extent(data, function(d) { return d[vvv]; })); // reset Y to get rid of NA values
    if(datna != null){
      dna = {}
      datna.forEach(function(e){dna[e.DateTime_UTC]=e[vvv]})
      y.domain(d3.extent(datna, function(d) { return d[vvv]; })); // reset Y to get rid of NA values
    }else{
      dna = {}
      data.forEach(function(e){dna[e.DateTime_UTC]=e[vvv]})
      y.domain(d3.extent(data, function(d) { return d[vvv]; })); // reset Y to get rid of NA values
    }
    d3.select("."+vvv).select(".axis--x").call(xAxis); //redraw axis
    var line = d3.line()
        .defined(function(d){return d[vvv];})
        .x(function(d) { return x(d.date); })
        .y(function(d) { return y(d[vvv]); });
    d3.select("."+vvv).selectAll(".dot")
        .attr("cx", line.x())
        .attr("cy", line.y())
    d3.select("."+vvv).selectAll('.sunriseset')
        .attr('x', function(d) { return x(d.set); })
        .attr('width', function(d) { return x(d.rise) - x(d.set); })
    // if(!zoom_in){ // adding na values
    d3.select("."+vvv).selectAll(".dot")
      .classed("outside", function(d) {
        return dna[d.DateTime_UTC] == null;
      });
    // }
    if(zoom_in){ // check for outside points
      // redraw points
      d3.select("."+vvv).selectAll(".dot")
        .classed("outside", function(d) {
          is_inplot = extent[0] > d.date || d.date > extent[1];
          return is_inplot;
        });
      // redraw sunriseset
      d3.selectAll(".sunriseset")
        .classed("outside", function(d) {
          is_inplot = extent[0] > d.rise || d.set > extent[1];
          return is_inplot;
        });

      // redraw backfill (commented parts will be relevant when brushing is added)
      var backfill = $("#backgraphlist").val();
      // var bf1 = $("#backgraphlist").val();
      // var bf2 = $("#backgraphlist_grab").val();
      // var bf_val = [bf1, bf2].find( function(x){ x != 'None' } );
      // var backfill = (bf_val != 'none' && bf_val != null) ? bf_val : 'None';
      BackGraph(backfill, vvv, data);
    }
  }
  d3.selectAll(".dot").classed("selected", false);
  d3.selectAll(".brush").call(brush.move, null);
  var selectedBrush;
}

// $('#flags2').selectize({
//     delimiter: ',',
//     persist: false,
//     create: function(input) { return {value: input,text: input} }
// });
