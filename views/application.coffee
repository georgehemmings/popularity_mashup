parse_csv_omit_empty = (values)->
  values.trim().split(/\s*,\s*/).filter( (value)-> 
    value isnt ''
  )
  
jQuery ->  
  $('form').submit ->
    false
  
  $('#compare').click (event)->    
    $charts = $('#charts')
    $charts.empty()  
  
    $bands = $('#bands')
    bands = parse_csv_omit_empty($bands.val())
    bands.splice(3)  
    $bands.val(bands.join(', '))
    
    unless bands.length is 0 
      $input = $('input')
      $input.attr('disabled', true)
      $input.ajaxStop( ->
        $input.attr('disabled', false)
      )
    
      for type in [
        'spotify_popularity',
        'facebook_likes',
        'lastfm_listeners',
        'twitter_followers' 
      ]
        data = [ { name: 'type', value: type }, { name: 'bands', value: bands } ]
    
        $('<div>').load('/chart', $.param(data), ->
          $('#charts').append $(this)
        )
        