global.jQuery = global.$ = require('jquery')
require('select2')
global._ = require('underscore')

siteInfoTemplate = _.template($('#site-info-template').html())
speciesCountRowTemplate = _.template($('#species-count-row-template').html())

createSiteObject = (code, [realm, ecoregion, name, lng, lat, numSurveys, speciesCounts]) ->
  code: code
  realm: realm
  ecoregion: ecoregion
  name: name
  latLng:
    lat: lat
    lng: lng
  numSurveys: numSurveys
  speciesCounts: speciesCounts

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

deferredJsons = $.when(
  $.getJSON('api-site-surveys.json'),
  $.getJSON('api-species.json'),
  $.getScript('https://maps.googleapis.com/maps/api/js?' +
              'key=AIzaSyCB7yf2Q30bz9qnsd0wy6KvtdTGyke7Fag&libraries=drawing,geometry')
)
deferredJsons.always ->
  $('body').removeClass('loading')
deferredJsons.fail ->
  $('.js-error-container').removeClass('hidden')
deferredJsons.done ([sites], [species]) ->
  map = new Map()
  sites = (createSiteObject(code, data) for code, data of sites)
  $selectSite = $('.js-site-select-container select').select2(placeholder: 'Select sites...')
  sites.sort (siteA, siteB) ->
    property =
      if siteA.ecoregion == siteB.ecoregion
        'code'
      else if siteA.realm == siteB.realm
        'ecoregion'
      else
        'realm'
    siteA[property].localeCompare(siteB[property])
  siteCodeToSite = {}

  populateSiteInfo = (numSurveys, speciesCounts, numSites = 1) ->
    $('#site-info').html(siteInfoTemplate(numSurveys: numSurveys, speciesCounts: speciesCounts, numSites: numSites))
    siteTableData = []
    for id, count of speciesCounts
      [name, commonName, speciesUrl, method, speciesClass] = species[id]
      siteTableData.push({
        name: name
        commonName: commonName or 'N/A'
        count: count
        percentage: (100 * count / numSurveys).toFixed(2)
        speciesClass: speciesClass
        method: switch method
          when 0 then 'M1'
          when 1 then 'M2'
          else 'Both'
      })

    $speciesTableBody = $('.js-species-table tbody')
    renderTableBody = (sortColumn = '-count') ->
      $speciesTableBody.html('')
      if sortColumn[0] == '-'
        sortColumn = sortColumn.slice(1)
        cmp = (elem) -> -elem[sortColumn]
      else
        cmp = sortColumn
      for rowData in _.sortBy(siteTableData, cmp)
        $speciesTableBody.append(speciesCountRowTemplate(rowData))
    $('.js-species-table thead a').click (event) ->
      event.preventDefault()
      renderTableBody($(this).data().sortColumn)
    renderTableBody()

    $('.js-export').click ->
      csvData = 'Scientific name\tCommon name\tMethod\tSpecies class\tSurveys seen\tTotal surveys\n'
      for row in siteTableData
        csvData += "#{row.name}\t#{row.commonName}\t#{row.method}\t#{row.speciesClass}\t#{row.count}\t#{numSurveys}\n"
      $(this).attr('download', 'rls-data-export.csv')
      $(this).attr('href', encodeURI("data:text/csv;charset=utf-8,#{csvData}"))

    $('.js-clear-selection').click ->
      $selectSite.val([]).trigger('change')

  populateMultiSiteInfo = (selectedSites) ->
    numSurveys = 0
    speciesCounts = {}
    for site in selectedSites
      numSurveys += site.numSurveys
      for speciesId, count of site.speciesCounts
        speciesCounts[speciesId] = 0 unless speciesCounts[speciesId]
        speciesCounts[speciesId] += count
    populateSiteInfo(numSurveys, speciesCounts, selectedSites.length)

  prevEcoregion = null
  $currOptGroup = null
  for site in sites
    do (site) ->
      if site.ecoregion != prevEcoregion
        prevEcoregion = site.ecoregion
        $currOptGroup = $('<optgroup>').attr('label', "#{site.realm}: #{site.ecoregion}")
        $currOptGroup.appendTo($selectSite)
      $('<option>').val(site.code).html("#{site.code}: #{site.name}").appendTo($currOptGroup)
      siteCodeToSite[site.code] = site
      map.createSiteMarker site, ->
        $selectSite.val([site.code]).trigger('change')
        map.highlightSiteMarker(site.code)

  $selectSite.change ->
    selectedSiteCodes = $selectSite.val()
    if selectedSiteCodes.length == 1
      site = siteCodeToSite[selectedSiteCodes[0]]
      populateSiteInfo(site.numSurveys, site.speciesCounts)
    else if selectedSiteCodes.length > 1
      populateMultiSiteInfo(siteCodeToSite[siteCode] for siteCode in selectedSiteCodes)
    else
      map.clearSelection()
      $('#site-info').html('')
  $selectSite.on('select2:select', (e) -> map.highlightSiteMarker(e.params.data.id))

  $('.js-site-select-container').removeClass('hidden')
  map.enableDrawing(sites, (selectedSiteCodes) -> $selectSite.val(selectedSiteCodes).trigger('change'))
