var margin = {top: 40, right: 60, bottom: 40, left: 40},
    width = $("#graphs").width() - margin.left - margin.right - 45, //45 for buttons
    height = 250 - margin.top - margin.bottom;
var parseDate = d3.utcParse("%Y-%m-%dT%H:%M:%S.%LZ");
var x = d3.scaleUtc().range([0, width]),
    y = d3.scaleLinear().range([height, 0]),
    xAxis = d3.axisBottom().scale(x).ticks(10).tickFormat(function(date, i){
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
var fullvarlist = []
var sundat;
// var flags;
var datna; //is this still needed?
var zoom_in;
var brushdown = false; //variable for if brushing all panels
var dott_undef //for disabling popup options if no points selected
// var flagdict = {}
var point_tooltip = d3.select("body").append("div")
    .attr("class", "tooltip")
    .style("opacity", 0);
var button_tooltip = d3.select("body").append("div")
    .attr("class", "tooltip button-tooltip")
    .style("opacity", 0);
var timeDiffArray = function(x){
  padright = x.concat(null)
  padleft = [null].concat(x)
  diffs = []
  for(var i = 0; i < padright.length; i++){
    diffs.push(padright[i] - padleft[i])
  }
  diffs = diffs.slice(1, diffs.length - 1)
  return(diffs)
}
var modeVal = function mode(arr){
    return arr.sort((a,b) =>
          arr.filter(v => v===a).length
        - arr.filter(v => v===b).length
    ).pop();
}

function Plots(variables, data, flags, outliers, page){

  data.forEach(function(d){ d.date = parseDate(d['DateTime_UTC']) });
  flags.forEach(function(d){ d.date = parseDate(d['DateTime_UTC']) });

  //populate full list of variables and determine whether model outputs exist
  fullvarlist = []
  $('#viz_vars').children('#variables').each(function(){
    fullvarlist.push($(this).val())
  })
  var sitecode = dsite.selectize.getValue()
  var model_exists = avail_mods.includes(sitecode) ? true : false

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

    var svg = d3.select("#graphs")
      .append('div').attr('id', 'svgrow_' + vvv)
      .append('div').attr('class', 'inline')
      .append("svg")
      .datum(data) //initialize and position
        .attr("class", vvv)
        .attr("width", width + margin.left + margin.right)
        .attr("height", height + margin.top + margin.bottom)
      .append("g")
        .attr("transform", "translate(" + margin.left + "," + margin.top + ")");
    svg.append("g") //x axis and x label
        .attr("class", "axis axis--x")
        .attr("transform", "translate(0," + (height-1) + ")") //1px adj shows lines
        .call(xAxis)
        .append("text") //label here
          .attr("fill", "#000")
          .attr("dy", "3em")
          .attr("dx", width)
          .style("text-anchor", "end")
          .text("DateTime (UTC)");
    svg.append("g")
        .attr("class", "axis axis--y")
        .call(d3.axisLeft().scale(y).ticks(6))
        // .selectAll('.line')
        //   .attr('stroke', 'red')
      .append("text")
        .attr("fill", "#000")
        .attr("dy", "-0.71em")
        .attr("dx", "0.71em")
        .attr('class', vvv + '_txt')
        .style("text-anchor", "start")
        .text(vvv);

    svg.append("g") //secondary axis for backgraphs and overlays
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
        dff[e.DateTime_UTC] = e.variable //so ugly...
        // flagdict[vvv].push(e.flag)
      }
    });
    // code for qaqc page
    if(page=="qaqc"){
      svg.on('dblclick',function(){
        redrawPoints(zoom_in=true, sbrush=selectedBrush, reset=true)
      });
      svg.append("g").attr("class", "brush")
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

          point_tooltip.transition()
            .duration(200)
            .style("opacity", .9);
          point_tooltip.html('Flag: ' + this_point_flaginfo.flag + '<br>Comment: ' +
            this_point_flaginfo.comment)
            .style("left", (d3.event.pageX) + "px")
            .style("top", (d3.event.pageY - 28) + "px");
          })
          .on("mouseout", function(d) {
            point_tooltip.transition()
              .duration(500)
              .style("opacity", 0);
          });

      //non-flagged points shouldnt register mouse activity
      // svg.selectAll('.dot:not(.flagdot)')
      //   .attr('pointer-events', 'none');

    } else { // viz page
      svg.selectAll(".vdot")
          .data(data.filter(function(d) { return d[vvv]; }))
        .enter().append("circle")
          .attr("class", "vdot")
          .attr("cx", line.x())
          .attr("cy", line.y())
          .attr("r", 2)
        .classed("flagdot", function(d){
          return vvv == dff[d.DateTime_UTC]
        })
        .filter('.flagdot')
        .attr('r', 3)
        .on("mouseover", function(d, j) {

          //add mouseover tooltips for each flagged point:
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

          point_tooltip.transition()
            .duration(200)
            .style("opacity", .9);
          point_tooltip.html('Flag: ' + this_point_flaginfo.flag + '<br>Comment: ' +
            this_point_flaginfo.comment)
            .style("left", (d3.event.pageX + 10) + "px")
            .style("top", (d3.event.pageY - 28) + "px");
          })
          .on("mouseout", function(d) {
            point_tooltip.transition()
              .duration(500)
              .style("opacity", 0);
          });

      //side buttons
      d3.select('#svgrow_' + vvv)
        .append('div')
          .attr('id', 'sidebuttons_' + vvv)
          .attr('class', 'inline').style('width', '45px')
        .append('button')
          .attr('id', 'interq_' + vvv)
          .attr('name', 'I' + vvv)
          .attr('class', 'btn btn-success btn-block')
          .text('H');
      if(vvv != 'DO_mgL'){
        d3.select('#sidebuttons_' + vvv)
          .append('button')
            .attr('id', 'interqDO_' + vvv)
            .attr('name', 'I' + vvv)
            .attr('class', 'btn btn-success btn-block')
            .text('DO');
      }
      if(vvv != 'Discharge_m3s'){
        d3.select('#sidebuttons_' + vvv)
          .append('button')
            .attr('id', 'interqQ_' + vvv)
            .attr('name', 'I' + vvv)
            .attr('class', 'btn btn-success btn-block')
            .property('disabled', function(d){
              if(! fullvarlist.includes('Discharge_m3s')){
                return true;
              }
            })
            .text('Q');
      }
      d3.select('#sidebuttons_' + vvv)
        .append('button')
          .attr('id', 'interqER_' + vvv)
          .attr('name', 'I' + vvv)
          .attr('class', 'btn btn-success btn-block')
          .property('disabled', function(d){
            if(! model_exists){
              return true;
            }
          })
          .text('ER');
      d3.select('#sidebuttons_' + vvv)
        .append('button')
          .attr('id', 'interqGP_' + vvv)
          .attr('name', 'I' + vvv)
          .attr('class', 'btn btn-success btn-block')
          .property('disabled', function(d){
            if(! model_exists){
              return true;
            }
          })
          .text('PP');

      //side button mouseover tooltips
      d3.selectAll("button[id^='interq_']").on("mouseover", function(d, j) {
        button_tooltip.transition()
          .duration(50)
          .style('background', '#89e6a1')
          .style("opacity", 1);
        button_tooltip.html('View historical interquartile range ' +
          '(25th-75th percentile, binned by day).')
          .style("left", (d3.event.pageX - 230) + "px")
          .style("top", (d3.event.pageY - 50) + "px");
      }).on("mouseout", function(d) {
        button_tooltip.transition()
          .duration(100)
          .style("opacity", 0);
      });

      d3.selectAll("button[id^='interqDO_']").on("mouseover", function(d, j) {
        button_tooltip.transition()
          .duration(50)
          // .style('background', '#ffd68c')
          .style('background', '#89e6a1')
          .style("opacity", 1);
        button_tooltip.html('View historical interquartile range of ' +
          'dissolved oxygen (25th-75th percentile, binned by day).')
          .style("left", (d3.event.pageX - 230) + "px")
          .style("top", (d3.event.pageY - 50) + "px");
      }).on("mouseout", function(d) {
        button_tooltip.transition()
          .duration(100)
          .style("opacity", 0);
      });

      d3.selectAll("button[id^='interqQ_']").on("mouseover", function(d, j) {
        button_tooltip.transition()
          .duration(50)
          .style('background', '#89e6a1')
          .style("opacity", 1);
        button_tooltip.html('View historical interquartile range of ' +
          'discharge (25th-75th percentile, binned by day).')
          .style("left", (d3.event.pageX - 230) + "px")
          .style("top", (d3.event.pageY - 50) + "px");
      }).on("mouseout", function(d) {
        button_tooltip.transition()
          .duration(100)
          .style("opacity", 0);
      });

      d3.selectAll("button[id^='interqER_']").on("mouseover", function(d, j) {
        button_tooltip.transition()
          .duration(50)
          .style('background', '#89e6a1')
          .style("opacity", 1);
        button_tooltip.html('View historical interquartile range of ' +
          'model-estimated ecosystem respiration ' +
          '(25th-75th percentile, binned by day).')
          .style("left", (d3.event.pageX - 230) + "px")
          .style("top", (d3.event.pageY - 50) + "px");
      }).on("mouseout", function(d) {
        button_tooltip.transition()
          .duration(100)
          .style("opacity", 0);
      });

      d3.selectAll("button[id^='interqGP_']").on("mouseover", function(d, j) {
        button_tooltip.transition()
          .duration(50)
          .style('background', '#89e6a1')
          .style("opacity", 1);
        button_tooltip.html('View historical interquartile range of ' +
          'model-estimated gross primary productivity ' +
          '(25th-75th percentile, binned by day).')
          .style("left", (d3.event.pageX - 230) + "px")
          .style("top", (d3.event.pageY - 50) + "px");
      }).on("mouseout", function(d) {
        button_tooltip.transition()
          .duration(100)
          .style("opacity", 0);
      });
    }

    svg.append("g")
        .attr("class", "foregraph");
  }
}

function Sunlight(variables, sundat){
  // console.time('sun')
  d3.selectAll(".sunriseset").remove();
  extent = x.domain();
  for (var i = 0; i < variables.length; ++i) {
    vvv = variables[i];
    d3.select("." + vvv).selectAll('.sunriseset')
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
  // console.timeEnd('sun')
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

function Interquartile(graph, ranges, req){

  //make new y axis scale and select graph
  var ynew = d3.scaleLinear().range([height, 0]);
  var yold = d3.scaleLinear().range([height, 0]),
  cur_foregraph = d3.select("." + graph).select(".foregraph");
  cur_backgraph = d3.select("." + graph).select(".backgraph");

  //remove previous graph and secondary axis if it exists
  cur_backgraph.selectAll("path").remove();
  cur_backgraph.selectAll("circle").remove();
  cur_foregraph.selectAll("path").remove();
  cur_foregraph.selectAll("circle").remove();
  d3.select('#' + graph + 'rightaxis').attr("visibility", "hidden");

  //set domains for left and right (old and new) y-axes
  flattened_ranges = [].concat(...ranges.map(x => [x[1], x[2]]));
  ynew.domain([d3.min(flattened_ranges), d3.max(flattened_ranges)]);
  yold.domain(d3.extent(data, function(d) { return d[graph]; }));

  //create accessor for interquartile range polygon
  var area = d3.area()
    .defined(function(d){
      if(d[1] == null || d[0] < x.domain()[0] || d[0] > x.domain()[1]){
        rrr = false
      } else {
        rrr = true
      }
      return rrr
    });
  area.x(d => x(d[0]));
  area.y0(d => ['DO', 'Q', 'ER', 'GPP'].includes(req) ? ynew(d[1]) : yold(d[1]))
  .y1(d => ['DO', 'Q', 'ER', 'GPP'].includes(req) ? ynew(d[2]) : yold(d[2]));


  //split interquartile data into chunks so that gaps can be shown
  var diffs = timeDiffArray(ranges.map(x => x[0]))
  var gapinds = diffs.map((x, i) => x == 86400000 ? null : i).filter(x => x != null)
  var bounds = [0].concat(gapinds).concat(diffs.length)
  var ranges_chunked = []
  for(var i = 0; i < bounds.length - 1; i++){
    ranges_chunked.push(ranges.slice(bounds[i] + 1, bounds[i+1] + 1))
      //+ 1 above converts from diff index to ranges index
  }

  //plot interquartile polygon in chunks
  for(r in ranges_chunked){
    if(ranges_chunked[r].length){
      cur_foregraph.append("path")
        .datum(ranges_chunked[r])
        .attr("class", "interquartile")
        .attr("d", area);
    }
  }

  //create line accessor and plot line for polygon portions where y0 == y1
  var intline = d3.line()
    .defined(d => d[2] == null ? false : true);
  intline.x(d => x(d[0]));
  intline.y(d => ['DO', 'Q', 'ER', 'GPP'].includes(req) ? ynew(d[2]) : yold(d[2]));

  for(r in ranges_chunked){
    if(ranges_chunked[r].length){
      cur_foregraph.append('path')
        .attr("d", intline(ranges_chunked[r]))
        .attr("class", 'interquartile_line');
    }
  }

  // refresh right-hand axis
  if(['DO', 'Q', 'ER', 'GPP'].includes(req)){
    d3.select("#" + graph + 'rightaxis')
      .call(d3.axisRight().scale(ynew).ticks(6))
      .attr('class', 'interquartile interquart_axis')
      .attr("visibility", "visible")
      .selectAll('text')
      .filter('.varlab')
      .remove();
    d3.select("#" + graph + 'rightaxis')
      .append("text")
        .attr("fill", "rgb(30, 209, 44)")
        .attr("dy", "-0.71em")
        .attr("dx", "0em")
        // .attr('class', vvv + '_txt')
        .attr('class', 'varlab')
        .style("text-anchor", "middle")
        .html(function(d){
          if(req == 'DO'){return 'DO_mgL'} else if(req == 'Q'){return 'Discharge_m3s'}
          else if(req == 'ER'){
            return 'O<tspan dy ="5">2</tspan><tspan dy ="-5"> gm</tspan>' +
            '<tspan dy ="-5">-2</tspan><tspan dy ="5">d</tspan><tspan dy ="-5">-1</tspan>'
          }
          else if(req == 'GPP'){
            return 'O<tspan dy ="5">2</tspan><tspan dy ="-5"> gm</tspan>' +
            '<tspan dy ="-5">-2</tspan><tspan dy ="5">d</tspan><tspan dy ="-5">-1</tspan>'
          }
        });
  } else {
    d3.select("#" + graph + 'rightaxis').attr("visibility", "hidden");
  }

}

function BackGraph(vvv, graph, data, type){

  //make new y axis scale and select graph
  var ynew = d3.scaleLinear().range([height, 0]);
  cur_backgraph = d3.select("." + graph).select(".backgraph")
  cur_foregraph = d3.select("." + graph).select(".foregraph");

  // remove previous graph and secondary axis if it exists
  cur_backgraph.selectAll("path").remove();
  cur_backgraph.selectAll("circle").remove();
  cur_foregraph.selectAll("path").remove();
  cur_foregraph.selectAll("circle").remove();

  if(typeof data !== 'string' || data !== 'None'){

    if(datna != null){
      ynew.domain(d3.extent(datna, function(d) { return d[vvv]; }));
    }else{
      ynew.domain(d3.extent(data, function(d) {
        return d[vvv]; }));
    }

    if(type == 'polygon'){
      var area = d3.area()
        .defined(function(d){
          if(d[vvv] == null || d.date < x.domain()[0] || d.date > x.domain()[1]){
            rrr = false
          } else {
            rrr = true
          }
          return rrr
        });
      area.x(function(d) {
        return x(d.date);
      });
      area.y0(height).y1(function(d) {
        return ynew(d[vvv]);
      });

      var diffs = timeDiffArray(data.map(x => x.date))
      mode_val = modeVal(diffs.slice(0, 25))
      var gapinds = diffs.map((x, i) => x == mode_val ? null : i).filter(x => x != null)
      var bounds = [0].concat(gapinds).concat(diffs.length)
      var data_chunked = []
      for(var i = 0; i < bounds.length - 1; i++){
        data_chunked.push(data.slice(bounds[i] + 1, bounds[i+1] + 1))
          //+ 1 above converts from diff index to ranges index
      }

      for(d in data_chunked){
        if(data_chunked[d].length){
          cur_backgraph.append("path")
            .datum(data_chunked[d])
            .attr("class", "backarea")
            .attr("d", area);
        }
      }

    } else { //type == 'point'

      var grabline = d3.line()
        .defined(function(d){ return d[vvv]; })
        .x(function(d){ return x(d.date); })
        .y(function(d){ return ynew(d[vvv]); });

      cur_foregraph.selectAll(".grabdot")
        .data(data.filter(function(d) { return d[vvv]; }))
        .enter().append("circle")
          .attr("class", "grabdot")
          .attr("cx", grabline.x())
          .attr("cy", grabline.y())
          .attr("r", 5);
    }
  }

  // refresh right axis
  d3.select("#" + graph + 'rightaxis')
    .selectAll('text')
    .filter('.varlab')
    .remove();
  if(typeof data !== 'string' || data !== 'None'){
    d3.select("#" + graph + 'rightaxis')
      .call(d3.axisRight().scale(ynew).ticks(6))
      .attr('class', 'backarea backarea_axis')
      .attr("display", "")
      .attr("visibility", "visible");
    d3.select("#" + graph + 'rightaxis')
      .append("text")
        .attr("fill", "rgb(173, 20, 219)")
        .attr("dy", "-0.71em")
        .attr("dx", "0em")
        .attr('class', 'varlab')
        .style("text-anchor", "middle")
        .text(vvv);
  }

}

$(function(){
  $("#backgraphlist").change(function () {

    var backfill = this.value;

    //reset the other dropdown, clear existing secondary axes
    $('#backgraphlist_grab').val('None'); //why doesn't this set off a feedback loop?
    d3.selectAll('[id$=rightaxis]').attr("display", "none");

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
            BackGraph(backfill, variables[i], backfilldata, type='polygon');
          }
        },
        error: function(error){
          console.log(error);
        }
      });

    } else {
      for (var i = 0; i < variables.length; ++i) {
        BackGraph(backfill, variables[i], data, type='polygon');
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
    + '<div class="v_align" style="width: .5em"></div><p class="v_align" style="font: 10pt sans-serif">Apply flag to <br> all selected <br> variables:</p> <input type="checkbox" id="fillbrush" value="yes"><div class="v_align" style="width: .5em"></div>'
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
      BackGraph(backfill, vvv, data, type='polygon');
    }
  }
  d3.selectAll(".dot").classed("selected", false);
  d3.selectAll(".brush").call(brush.move, null);
  var selectedBrush;
}
