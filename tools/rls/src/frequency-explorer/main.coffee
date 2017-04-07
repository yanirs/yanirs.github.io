global.jQuery = global.$ = require('jquery')
require('select2')
global._ = require('underscore')
lazyLoad = new (require('vanilla-lazyload'))()
util = require('../util.js.tmp')

siteInfoTemplate = _.template($('#site-info-template').html())
speciesCountRowTemplate = _.template($('#species-count-row-template').html())

class DummyMap
  createSiteMarker: ->
  highlightSiteMarker: ->
  enableDrawing: ->
  clearSelection: ->

class Map
  constructor: ->
    # Fairly zoomed out map, centred on Australia.
    @gmap = new google.maps.Map($('.js-map')[0], {
      center: { lat: -30, lng: 150 }
      zoom: 3
      scrollwheel: false
      streetViewControl: false
    })
    @siteCodeToMarker = {}
    @siteCodeToInfoWindow = {}

  showSiteInfoWindow: (siteCode) ->
    @openInfoWindow.close() if @openInfoWindow
    @openInfoWindow = @siteCodeToInfoWindow[siteCode]
    @openInfoWindow.open(@gmap, @siteCodeToMarker[siteCode])

  createSiteMarker: (site, handleSiteSelection) ->
    marker = new google.maps.Marker
      position: site.latLng
      map: @gmap
      title: site.name
    @siteCodeToMarker[site.code] = marker
    @siteCodeToInfoWindow[site.code] = new google.maps.InfoWindow
      content: "<b>#{site.name} (#{site.code})</b><br>
                #{site.realm} &ndash; #{site.ecoregion}<br>
                <i>#{site.latLng.lat}, #{site.latLng.lng}</i>"
    google.maps.event.addListener(marker, 'click', handleSiteSelection)

  highlightSiteMarker: (siteCode, bounceTimeout = 2500) ->
    @clearSelection()
    @showSiteInfoWindow(siteCode)
    marker = @siteCodeToMarker[siteCode]
    @gmap.panTo(marker.getPosition())
    marker.setAnimation(google.maps.Animation.BOUNCE)
    window.setTimeout((-> marker.setAnimation(null)), bounceTimeout)

  enableDrawing: (sites, handleSitesSelected) ->
    drawingManager = new google.maps.drawing.DrawingManager
      drawingControl: true
      drawingControlOptions:
        position: google.maps.ControlPosition.TOP_RIGHT
        drawingModes: ['polygon']
      map: @gmap
    google.maps.event.addListener drawingManager, 'polygoncomplete', (polygon) =>
      @clearSelection()
      drawingManager.setDrawingMode(null)
      @currentPolygon = polygon
      containsLocation = google.maps.geometry.poly.containsLocation
      handleSitesSelected(site.code for site in sites when containsLocation(new google.maps.LatLng(site.latLng),
                                                                            polygon))

  clearSelection: ->
    @currentPolygon.setMap(null) if @currentPolygon
    @openInfoWindow.close() if @openInfoWindow

util.loadSurveyData (surveyData) ->
  if google?
    map = new Map()
  else
    map = new DummyMap()
    $('.js-map').addClass('alert alert-danger').html('Map loading failed')
  $selectSite = $('.js-site-select-container select').select2(placeholder: 'Select sites...')

  populateSiteInfo = (numSurveys, speciesCounts, siteCodes) ->
    $('#site-info').html(siteInfoTemplate(numSurveys: numSurveys, speciesCounts: speciesCounts, siteCodes: siteCodes))
    siteTableData = []
    for id, count of speciesCounts
      rowData = _.extend({ count: count, percentage: (100 * count / numSurveys).toFixed(2) },
                         surveyData.species[id])
      imageCells = []
      # Iterate over range rather than images to ensure the cell number is consistent.
      for i in [0..4]
        image = rowData.images[i]
        if image
          imageCells.push("""<td><a href="#{image}" target='_blank'><img data-original="#{image}"></a></td>""")
        else
          imageCells.push('<td></td>')
      rowData.imageRow = imageCells.join('')
      siteTableData.push(rowData)
    $speciesTableBody = $('.js-species-table tbody')
    renderTableBody = (sortColumn = '-count') ->
      $speciesTableBody.html('')
      if sortColumn[0] == '-'
        sortColumn = sortColumn.slice(1)
        cmp = (elem) -> -elem[sortColumn]
      else
        cmp = sortColumn
      # Assign sorted result to allow sorting by multiple columns (_.sortBy is stable)
      siteTableData = _.sortBy(siteTableData, cmp)
      for rowData in siteTableData
        $speciesTableBody.append(speciesCountRowTemplate(rowData))
      $('.js-image-row').hide()
      lazyLoad.update()
    $('.js-species-table thead a').click (event) ->
      event.preventDefault()
      renderTableBody($(this).data().sortColumn)
    renderTableBody()

    $('.js-export').click ->
      csvData = 'Scientific name\tCommon name\tMethod\tSurveys seen\tTotal surveys\n'
      for row in siteTableData
        csvData += "#{row.name}\t#{row.commonName}\t#{row.method}\t#{row.count}\t#{numSurveys}\n"
      $(this).attr('download', 'rls-data-export.csv')
      $(this).attr('href', encodeURI("data:text/csv;charset=utf-8,#{csvData}"))

    $('.js-clear-selection').click ->
      $selectSite.val([]).trigger('change')

    $('.js-images').click ->
      $('.js-image-row').toggle()
      lazyLoad.handleScroll()

  prevEcoregion = null
  $currOptGroup = null
  for site in surveyData.sites
    do (site) ->
      if site.ecoregion != prevEcoregion
        prevEcoregion = site.ecoregion
        $currOptGroup = $('<optgroup>').attr('label', "#{site.realm}: #{site.ecoregion}")
        $currOptGroup.appendTo($selectSite)
      $('<option>').val(site.code).html("#{site.code}: #{site.name}").appendTo($currOptGroup)
      map.createSiteMarker site, ->
        $selectSite.val([site.code]).trigger('change')
        map.highlightSiteMarker(site.code)

  $selectSite.change ->
    siteCodes = $selectSite.val()
    if siteCodes.length == 0
      map.clearSelection()
      $('#site-info').html('')
    else
      [numSurveys, speciesCounts] = surveyData.sumSites(siteCodes)
      populateSiteInfo(numSurveys, speciesCounts, siteCodes)
  $selectSite.on('select2:select', (e) -> map.highlightSiteMarker(e.params.data.id))

  $('.js-site-select-container').removeClass('hidden')
  map.enableDrawing(surveyData.sites, (siteCodes) -> $selectSite.val(siteCodes).trigger('change'))
